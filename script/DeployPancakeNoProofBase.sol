// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {DeployPancakeNoProofXChain} from "./DeployPancakeNoProofXChain.sol";

contract DeplotPancakeNoProofBase is DeployPancakeNoProofXChain(0xe432150cce91c13a887f7D836923d5597adD8E31) {
    function run() public override {
        vm.createSelectFork(vm.rpcUrl("base"));
        super.run();
    }
}