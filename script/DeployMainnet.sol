// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {EthereumStateSender} from "src/EthereumStateSender.sol";

contract DeploySideChains is Script {
    EthereumStateSender sender;

    address internal constant DEPLOYER = 0x0dE5199779b43E13B3Bec21e91117E18736BC1A8;

    function run() public {
        vm.startBroadcast(DEPLOYER);

        sender = new EthereumStateSender();

        vm.stopBroadcast();
    }
}
