// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IAxelarGasReceiverProxy {
    function payNativeGasForContractCall(
        address sender,
        string memory destinationChain,
        string memory destinationAddress,
        bytes memory payload,
        address refundAddress
    ) external payable;
}
