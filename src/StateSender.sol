// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {LibString} from "solady/utils/LibString.sol";
import {IAxelarGateway} from "src/interfaces/IAxelarGateway.sol";
import {IAxelarGasReceiverProxy} from "src/interfaces/IAxelarGasReceiverProxy.sol";

/// @title StateSender
/// @notice Sends weekly period block + block hash to a set of destination chains through Axelar
/// @dev This contract uses Axelar network for cross-chain communication
abstract contract StateSender {
    using LibString for address;

    address public governance;
    address public futureGovernance;

    address public immutable axelarGateway;
    address public immutable axelarGasReceiver;

    uint256 public sendBlockHashMinValue;
    uint256 public setRecipientMinValue;

    struct ChainContract {
        string chain;
        address[] contracts;
    }

    ChainContract[] public chains;
    mapping(uint256 => uint256) public blockNumbers;
    mapping(uint256 => bytes32) public blockHashes;

    mapping(string => uint256) private chainIndex;
    mapping(string => bool) private chainExists;

    event ChainRemoved(string indexed chain);
    event RecipientMinValueSet(uint256 newValue);
    event SendBlockHashMinValueSet(uint256 newValue);
    event GovernanceChanged(address indexed newGovernance);
    event ChainAdded(string indexed chain, address[] indexed contracts);
    event RecipientSet(address indexed sender, address indexed recipient, string indexed chain);

    error ChainAlreadyExists();
    error ChainNotFound();
    error GovernanceOnly();
    error InsufficientValue();
    error AlreadySent();
    error TooCloseToCurrentPeriod();

    constructor(
        address _governance,
        address _axelarGateway,
        address _axelarGasReceiver,
        uint256 _sendBlockHashMinValue,
        uint256 _setRecipientMinValue
    ) payable {
        governance = _governance;
        axelarGateway = _axelarGateway;
        axelarGasReceiver = _axelarGasReceiver;
        sendBlockHashMinValue = _sendBlockHashMinValue;
        setRecipientMinValue = _setRecipientMinValue;
    }

    modifier onlyGovernance() {
        if (msg.sender != governance) revert GovernanceOnly();
        _;
    }

    /// @notice Sends the block hash to all contracts on all chains
    /// @dev Requires payment to cover gas fees and checks for timing to avoid too frequent updates
    function sendBlockHash() external payable {
        uint256 currentPeriod = getCurrentPeriod();
        uint256 amountOfContracts = getEnabledContracts();

        if (msg.value < sendBlockHashMinValue * amountOfContracts) revert InsufficientValue();
        if (block.timestamp < currentPeriod + 5 minutes) revert TooCloseToCurrentPeriod();
        if (blockNumbers[currentPeriod] != 0) revert AlreadySent();

        ChainContract[] memory chainsToSend = chains;
        uint256 chainsToSendLength = chainsToSend.length;

        uint256 valuePerContract = msg.value / amountOfContracts;

        blockNumbers[currentPeriod] = block.number - 1;
        blockHashes[currentPeriod] = blockhash(block.number - 1);

        for (uint256 i = 0; i < chainsToSendLength;) {
            ChainContract memory chain = chainsToSend[i];
            for (uint256 j = 0; j < chain.contracts.length;) {
                address contractAddress = chain.contracts[j];
                _sendBlockHash(contractAddress, chain.chain, valuePerContract, currentPeriod);
                unchecked {
                    j++;
                }
            }
            unchecked {
                i++;
            }
        }
    }

    /// @notice Sets the recipient for an address on oracle
    /// @param chain Name of the chain
    /// @param contracts List of contract addresses on the chain
    /// @param recipient Address to set as the recipient
    function setRecipient(string calldata chain, address[] calldata contracts, address recipient) external payable {
        uint256 valuePerContract = msg.value / contracts.length;
        if (!chainExists[chain]) revert ChainNotFound();
        if (valuePerContract < setRecipientMinValue) revert InsufficientValue();

        for (uint256 i = 0; i < contracts.length;) {
            string memory _destinationContract = contracts[i].toHexStringChecksumed();
            bytes memory payload = abi.encodeWithSignature("setRecipient(address,address)", msg.sender, recipient);

            IAxelarGasReceiverProxy(axelarGasReceiver).payNativeGasForContractCall{value: valuePerContract}(
                address(this), chain, _destinationContract, payload, msg.sender
            );

            IAxelarGateway(axelarGateway).callContract(chain, _destinationContract, payload);

            unchecked {
                i++;
            }
        }

        emit RecipientSet(msg.sender, recipient, chain);
    }

    function _sendBlockHash(
        address destinationContract,
        string memory destinationChain,
        uint256 value,
        uint256 currentPeriod
    ) internal {
        string memory destinationContractHex = destinationContract.toHexStringChecksumed();
        bytes memory payload = abi.encodeWithSignature(
            "setEthBlockHash(uint256,bytes32)", blockNumbers[currentPeriod], blockHashes[currentPeriod]
        );

        IAxelarGasReceiverProxy(axelarGasReceiver).payNativeGasForContractCall{value: value}(
            address(this), destinationChain, destinationContractHex, payload, msg.sender
        );

        IAxelarGateway(axelarGateway).callContract(destinationChain, destinationContractHex, payload);
    }

    ////////////////////////////////////////////////////////////
    /// --- GOVERNANCE
    ////////////////////////////////////////////////////////////

    /// @notice Adds a new chain and its associated contracts to the list
    /// @dev Can only be called by the governance address
    /// @param chain Name of the chain
    /// @param contracts List of contract addresses on the new chain
    function addChain(string calldata chain, address[] calldata contracts) external onlyGovernance {
        if (chainExists[chain]) revert ChainAlreadyExists();
        chains.push(ChainContract({chain: chain, contracts: contracts}));
        chainIndex[chain] = chains.length - 1;
        chainExists[chain] = true;
        emit ChainAdded(chain, contracts);
    }

    /// @notice Removes a chain and its associated contracts from the list
    /// @dev Can only be called by the governance address
    /// @param chain Name of the chain
    function removeChain(string calldata chain) external onlyGovernance {
        if (!chainExists[chain]) revert ChainNotFound();
        uint256 index = chainIndex[chain];
        uint256 lastIndex = chains.length - 1;
        if (index != lastIndex) {
            chains[index] = chains[lastIndex];
            chainIndex[chains[lastIndex].chain] = index;
        }
        chains.pop();
        delete chainIndex[chain];
        delete chainExists[chain];
        emit ChainRemoved(chain);
    }

    /// @notice Sends the block hash to all contracts on a specific chain
    /// @dev Can only be called by the governance address
    /// @param chain Name of the chain
    /// @param contracts List of contract addresses on the chain
    /// @param blockNumber Block number to send
    /// @param blockHash Block hash to send
    /// @dev Do not care about already sent or too close, only for emergency purposes
    function sendBlockHashEmergency(
        string calldata chain,
        address[] calldata contracts,
        uint256 blockNumber,
        bytes32 blockHash
    ) external payable onlyGovernance {
        if (msg.value < sendBlockHashMinValue * contracts.length) revert InsufficientValue();

        uint256 valuePerContract = msg.value / contracts.length;

        for (uint256 i = 0; i < contracts.length;) {
            string memory destinationContractHex = contracts[i].toHexStringChecksumed();
            bytes memory payload = abi.encodeWithSignature("setEthBlockHash(uint256,bytes32)", blockNumber, blockHash);

            IAxelarGasReceiverProxy(axelarGasReceiver).payNativeGasForContractCall{value: valuePerContract}(
                address(this), chain, destinationContractHex, payload, msg.sender
            );

            IAxelarGateway(axelarGateway).callContract(chain, destinationContractHex, payload);

            unchecked {
                i++;
            }
        }
    }

    function setMinValueForSetRecipient(uint256 newValue) external onlyGovernance {
        setRecipientMinValue = newValue;
        emit RecipientMinValueSet(newValue);
    }

    function setSendBlockHashMinValue(uint256 newValue) external onlyGovernance {
        sendBlockHashMinValue = newValue;
        emit SendBlockHashMinValueSet(newValue);
    }

    /// @notice Transfer the governance to a new address.
    /// @param _governance Address of the new governance.
    function transferGovernance(address _governance) external onlyGovernance {
        futureGovernance = _governance;
    }

    /// @notice Accept the governance transfer.
    function acceptGovernance() external {
        if (msg.sender != futureGovernance) revert GovernanceOnly();

        governance = msg.sender;

        /// Reset the future governance.
        futureGovernance = address(0);

        emit GovernanceChanged(msg.sender);
    }

    ////////////////////////////////////////////////////////////
    /// --- VIEW FUNCTIONS
    ////////////////////////////////////////////////////////////

    /// @notice Retrieves chain and contract information by index
    /// @param index Index of the chain in the array
    /// @return ChainContract The chain and its contracts
    function getChain(uint256 index) public view returns (ChainContract memory) {
        return chains[index];
    }

    /// @notice Calculates the current period based on weekly intervals
    /// @return uint256 The start of the current weekly period
    function getCurrentPeriod() public view returns (uint256) {
        return (block.timestamp / 1 weeks) * 1 weeks;
    }

    /// @notice Counts all enabled contracts across all chains
    /// @return count Total number of enabled contracts
    function getEnabledContracts() public view returns (uint256 count) {
        uint256 chainsLength = chains.length;
        for (uint256 i = 0; i < chainsLength;) {
            count += chains[i].contracts.length;
            unchecked {
                i++;
            }
        }
    }
}
