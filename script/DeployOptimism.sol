// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import './DeployMulti.sol';


contract DeployOptimism is DeployMulti {
    function run() public override {
        vm.createSelectFork(vm.rpcUrl("optimism"));
        super.run();
    }
}
