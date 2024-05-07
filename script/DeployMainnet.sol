// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import {EthereumStateSender} from "src/EthereumStateSender.sol";

contract DeploySideChains is Script {
    EthereumStateSender sender;

    address internal constant DEPLOYER = 0x8898502BA35AB64b3562aBC509Befb7Eb178D4df;

    function run() public {
        vm.startBroadcast(DEPLOYER);

        sender = new EthereumStateSender(DEPLOYER);

        // Setting the receiver contract as Axelar Executable (on Arbitrum)

        vm.stopBroadcast();
    }
}
