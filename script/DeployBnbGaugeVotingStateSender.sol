// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {BnbGaugeVotingStateSender} from "src/BnbGaugeVotingStateSender.sol";

contract DeplotBnbGaugeVotingStateSender is Script {
    address internal constant DEPLOYER = 0x000755Fbe4A24d7478bfcFC1E561AfCE82d1ff62;
    BnbGaugeVotingStateSender internal stateSender;

    function run() public {
        vm.createSelectFork(vm.rpcUrl("bsc"));
        vm.startBroadcast(DEPLOYER);

        stateSender = new BnbGaugeVotingStateSender(DEPLOYER, 0.003 ether, 0.001 ether);
        assert(stateSender.governance() == DEPLOYER);

        vm.stopBroadcast();
    }
}
