// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.20;

import {IAxelarGasReceiverProxy} from "src/interfaces/IAxelarGasReceiverProxy.sol";


contract MockAxelarGasReceiver is IAxelarGasReceiverProxy {

    // Storings
    address public sender;
    string public destinationChain;
    string public destinationAddress;
    bytes public payload;
    address public refundAddress;

    constructor() {}
    function payNativeGasForContractCall(address _sender, string memory _destinationChain, string memory _destinationAddress, bytes memory _payload, address _refundAddress) external payable {
        sender = _sender;
        destinationChain = _destinationChain;
        destinationAddress = _destinationAddress;
        payload = _payload;
        refundAddress = _refundAddress;
    }
}