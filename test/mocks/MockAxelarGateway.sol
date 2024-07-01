// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.20;

import {IAxelarGateway} from "src/interfaces/IAxelarGateway.sol";

contract MockAxelarGateway is IAxelarGateway {
    struct DestinationData {
        string chain;
        string storedAddress;
        bytes payload;
    }

    mapping(uint256 => DestinationData) private destinations;
    uint256 public destinationsCount;

    constructor() {}

    function callContract(string memory _destinationChain, string memory _destinationAddress, bytes memory _payload)
        external
    {
        DestinationData storage destination = destinations[destinationsCount++];
        destination.chain = _destinationChain;
        destination.storedAddress = _destinationAddress;
        destination.payload = _payload;
    }

    // view to access destination

    function getDestination(uint256 index) external view returns (string memory, string memory, bytes memory) {
        return (destinations[index].chain, destinations[index].storedAddress, destinations[index].payload);
    }

    // Overrides
    function callContractWithToken(
        string memory _destinationChain,
        string memory _destinationAddress,
        bytes memory _payload,
        string memory _symbol,
        uint256 _amount
    ) external {}

    function sendToken(
        string memory _destinationChain,
        string memory _destinationAddress,
        string memory _symbol,
        uint256 _amount
    ) external {}

    function isContractCallApproved(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        address contractAddress,
        bytes32 payloadHash
    ) external view returns (bool) {
        return false;
    }

    function isContractCallAndMintApproved(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        address contractAddress,
        bytes32 payloadHash,
        string calldata symbol,
        uint256 amount
    ) external view returns (bool) {
        return false;
    }

    function validateContractCall(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes32 payloadHash
    ) external returns (bool) {
        return false;
    }

    function validateContractCallAndMint(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes32 payloadHash,
        string calldata symbol,
        uint256 amount
    ) external returns (bool) {
        return false;
    }

    function authModule() external view override returns (address) {}

    function tokenDeployer() external view override returns (address) {}

    function tokenMintLimit(string memory symbol) external view override returns (uint256) {}

    function tokenMintAmount(string memory symbol) external view override returns (uint256) {}

    function allTokensFrozen() external view override returns (bool) {}

    function implementation() external view override returns (address) {}

    function tokenAddresses(string memory symbol) external view override returns (address) {}

    function tokenFrozen(string memory symbol) external view override returns (bool) {}

    function isCommandExecuted(bytes32 commandId) external view override returns (bool) {}

    function adminEpoch() external view override returns (uint256) {}

    function adminThreshold(uint256 epoch) external view override returns (uint256) {}

    function admins(uint256 epoch) external view override returns (address[] memory) {}

    function setTokenMintLimits(string[] calldata symbols, uint256[] calldata limits) external override {}

    function upgrade(address newImplementation, bytes32 newImplementationCodeHash, bytes calldata setupParams)
        external
        override
    {}

    function setup(bytes calldata params) external override {}

    function execute(bytes calldata input) external override {}
}
