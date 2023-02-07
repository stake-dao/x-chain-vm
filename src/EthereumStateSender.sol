// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LibString} from "solady/utils/LibString.sol";
import {IAxelarGateway} from "src/interfaces/IAxelarGateway.sol";

contract EthereumStateSender {
    using LibString for address;

    address public constant AXELAR_GATEWAY = 0x4F4495243837681061C4743b74B3eEdf548D56A5;

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

    /// @notice     Send a blockhash to a destination chain (it will use the current block's blockhash)
    /// @param      destinationChain The destination chain
    /// @param      destinationContract The destination contract
    function sendBlockhash(string calldata destinationChain, address destinationContract)
        public
    {
        uint256 currentPeriod = getCurrentPeriod();

        // Only one submission per period
        if (blockNumbers[currentPeriod] == 0) {
            blockHashes[currentPeriod] = blockhash(block.number);
            blockNumbers[currentPeriod] = block.number;
        }

        if (destinationChains[currentPeriod][destinationChain] == 0) {
            string memory _destinationContract = destinationContract.toHexStringChecksumed();

            IAxelarGateway(AXELAR_GATEWAY).callContract(
                destinationChain,
                _destinationContract,
                abi.encode("setEthBlockHash(uint256,bytes32)", blockNumbers[currentPeriod], blockHashes[currentPeriod])
            );

            destinationChains[currentPeriod][destinationChain] += 1;

            emit BlockhashSent(blockNumbers[currentPeriod], blockHashes[currentPeriod], destinationChain);
        }
    }

    /// @notice     Send a blockhash to a a list of destination chains (it will use the current block's blockhash)
    /// @param      _destinationChains The destination chains array
    /// @param      _destinationContracts The destination contracts array
    function sendBlockhash(string[] calldata _destinationChains, address[] calldata _destinationContracts) external {
        uint256 lenght = _destinationChains.length;
        for (uint256 i; i < lenght;) {
            sendBlockhash(_destinationChains[i], _destinationContracts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice    Set a recipient for a destination chain
    /// @param     destinationChain The destination chain
    /// @param     destinationContract The destination contract
    /// @param     _recipient The recipient
    function setRecipient(string calldata destinationChain, address destinationContract, address _recipient) external {
        string memory _destinationContract = destinationContract.toHexStringChecksumed();

        IAxelarGateway(AXELAR_GATEWAY).callContract(
            destinationChain, _destinationContract, abi.encode("setRecipient(address,address)", msg.sender, _recipient)
        );

        emit RecipientSet(msg.sender, _recipient, destinationChain);
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

    function getCurrentPeriod() public view returns (uint256) {
        return (block.timestamp / 1 weeks * 1 weeks);
    }
}
