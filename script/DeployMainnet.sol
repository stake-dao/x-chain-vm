// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {EthereumStateSender} from "src/EthereumStateSender.sol";

contract DeploySideChains is Script {
    EthereumStateSender sender;

    function run() public {
        vm.startBroadcast();

        sender = new EthereumStateSender();

        vm.stopBroadcast();
    }
}
