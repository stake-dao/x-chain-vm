// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LibString} from "solady/utils/LibString.sol";
import {IAxelarGateway} from "src/interfaces/IAxelarGateway.sol";
import {IAxelarGasReceiverProxy} from "src/interfaces/IAxelarGasReceiverProxy.sol";

contract EthereumStateSender {
    using LibString for address;

    error ONLY_ADMIN();
    error VALUE_TOO_LOW();

    address public admin;

    address public constant AXELAR_GATEWAY = 0x4F4495243837681061C4743b74B3eEdf548D56A5;
    address public constant AXELAR_GAS_RECEIVER = 0x2d5d7d31F671F86C782533cc367F14109a082712;

    uint256 public sendBlockHashMinValue = 3000000000000000; // 0.003 ETH
    uint256 public setRecipientMinValue = 1000000000000000; // 0.001 ETH

    mapping(uint256 => uint256) public blockNumbers;
    mapping(uint256 => bytes32) public blockHashes;
    mapping(uint256 => mapping(string => uint256)) public destinationChains;

    /// @notice Emitted when a recipient is set
    /// @param _sender The sender of the transaction
    /// @param _recipient The recipient of the transaction
    /// @param _destinationChain The destination chain
    event RecipientSet(address indexed _sender, address indexed _recipient, string _destinationChain);

    /// @notice Emitted when a blockhash is sent
    /// @param _blockNumber The block number
    /// @param _blockHash The block hash
    /// @param _destinationChain The destination chain
    event BlockhashSent(uint256 indexed _blockNumber, bytes32 _blockHash, string _destinationChain);

    /// @notice Emitted when a new admin is set
    /// @param _admin The admin address
    event AdminSet(address _admin);

    /// @notice Emitted when a new sendBlockHashMinValue is set
    /// @param _minValue The min eth value to pass on the call 
    event SendBlockhashMinValueSet(uint256 _minValue);

    /// @notice Emitted when a new setRecipientMinValue is set
    /// @param _minValue The min eth value to pass on the call 
    event SetRecipientMinValueSet(uint256 _minValue);

    constructor(address _admin) {
        admin = _admin;
    }

    /// @notice     Send a blockhash to a destination chain (it will use the previous block's blockhash)
    /// @param      _destinationChain The destination chain
    /// @param      _destinationContract The destination contract
    function sendBlockhash(string calldata _destinationChain, address _destinationContract) public payable {
        if (msg.value < sendBlockHashMinValue) revert VALUE_TOO_LOW();
        uint256 currentPeriod = getCurrentPeriod();

        // Only one submission per period
        if (blockNumbers[currentPeriod] == 0 && currentPeriod + 5 minutes < block.timestamp) {
            blockHashes[currentPeriod] = blockhash(block.number - 1);
            blockNumbers[currentPeriod] = block.number - 1;
        }

        if (blockNumbers[currentPeriod] != 0 && destinationChains[currentPeriod][_destinationChain] == 0) {
            _sendBlockhash(_destinationContract, _destinationChain, currentPeriod);
        }
    }

    /// @notice     Send a blockhash to a list of destination chains (it will use the current block's blockhash)
    /// @param      _destinationChains The destination chains array
    /// @param      _destinationContracts The destination contracts array
    function sendBlockhash(string[] calldata _destinationChains, address[] calldata _destinationContracts) external payable {
        uint256 lenght = _destinationChains.length;
        if (msg.value < sendBlockHashMinValue * lenght) revert VALUE_TOO_LOW();
        for (uint256 i; i < lenght;) {
            sendBlockhash(_destinationChains[i], _destinationContracts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice     Send a blockhash to a destination chain, function used only in emergency cases
    /// @param      _destinationChain The destination chain 
    /// @param      _destinationContract The destination contract
    function sendBlockhashEmergency(string calldata _destinationChain, address _destinationContract) external payable {
        if(msg.sender != admin) revert ONLY_ADMIN();
        if (msg.value < sendBlockHashMinValue) revert VALUE_TOO_LOW();
        uint256 currentPeriod = getCurrentPeriod();
        _sendBlockhash(_destinationContract, _destinationChain, currentPeriod);
    }

    /// @notice     Internal function to send a blockhash to a destination chain
    /// @param      destinationChain The destination chain 
    /// @param      destinationContract The destination contract
    /// @param      currentPeriod Current period
    function _sendBlockhash(address destinationContract, string calldata destinationChain, uint256 currentPeriod) internal {
        string memory _destinationContract = destinationContract.toHexStringChecksumed();
        bytes memory payload =
            abi.encodeWithSignature("setEthBlockHash(uint256,bytes32)", blockNumbers[currentPeriod], blockHashes[currentPeriod]);
        // pay gas in eth
        // the gas in exceed will be reimbursed to the msg.sender
        IAxelarGasReceiverProxy(AXELAR_GAS_RECEIVER).payNativeGasForContractCall{value: msg.value}(
            address(this), destinationChain, _destinationContract, payload, msg.sender
        );

        IAxelarGateway(AXELAR_GATEWAY).callContract(destinationChain, _destinationContract, payload);

        destinationChains[currentPeriod][destinationChain] += 1;

        emit BlockhashSent(blockNumbers[currentPeriod], blockHashes[currentPeriod], destinationChain);
    }

    /// @notice    Set a recipient for a destination chain
    /// @param     destinationChain The destination chain
    /// @param     destinationContract The destination contract
    /// @param     recipient The recipient
    function setRecipient(string calldata destinationChain, address destinationContract, address recipient) external payable {
        if (msg.value < setRecipientMinValue) revert VALUE_TOO_LOW();
        string memory _destinationContract = destinationContract.toHexStringChecksumed();
        bytes memory payload =
                abi.encodeWithSignature("setRecipient(address,address)", msg.sender, recipient);

        IAxelarGasReceiverProxy(AXELAR_GAS_RECEIVER).payNativeGasForContractCall{value: msg.value}(
                address(this), destinationChain, _destinationContract, payload, msg.sender
            );

        IAxelarGateway(AXELAR_GATEWAY).callContract(
            destinationChain, _destinationContract, payload
        );

        emit RecipientSet(msg.sender, recipient, destinationChain);
    }

    /// @notice    Set min value (ETH) to send during the sendBlockhash() call
    /// @param     minValue min value to set
    function setSendBlockHashMinValue(uint256 minValue) external {
        if (msg.sender != admin) revert ONLY_ADMIN();
        sendBlockHashMinValue = minValue;
        emit SendBlockhashMinValueSet(minValue);
    }

    /// @notice    Set min value (ETH) to send during the setRecipient() call
    /// @param     minValue min value to set
    function setSetRecipientMinValue(uint256 minValue) external {
        if (msg.sender != admin) revert ONLY_ADMIN();
        setRecipientMinValue = minValue;
        emit SetRecipientMinValueSet(minValue);
    }

    /// @notice    Set a new admin
    /// @param     _admin admin address
    function setAdmin(address _admin) external {
        if (msg.sender != admin) revert ONLY_ADMIN();
        admin = _admin;
        emit AdminSet(_admin);
    }

    /// @notice   Generate proof parameters for a given user, gauge and time
    /// @param    _user The user
    /// @param    _gauge The gauge
    /// @param    _time The time
    function generateEthProofParams(address _user, address _gauge, uint256 _time)
        external
        view
        returns (address, address, uint256, uint256[6] memory _positions, uint256)
    {
        uint256 lastUserVotePosition = uint256(keccak256(abi.encode(keccak256(abi.encode(11, _user)), _gauge)));
        _positions[0] = lastUserVotePosition;
        uint256 pointWeightsPosition =
            uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(12, _gauge)), _time)))));
        uint256 i;
        for (i = 0; i < 2; i++) {
            _positions[1 + i] = pointWeightsPosition + i;
        }

        uint256 voteUserSlopePosition =
            uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(9, _user)), _gauge)))));
        for (i = 0; i < 3; i++) {
            _positions[3 + i] = voteUserSlopePosition + i;
        }
        return (_user, _gauge, _time, _positions, block.number);
    }

    /// @notice   Get current period (last thursday at midnight utc time)
    function getCurrentPeriod() public view returns (uint256) {
        return (block.timestamp / 1 weeks * 1 weeks);
    }

    receive() external payable {}
}
