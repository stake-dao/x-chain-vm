// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

import {PlatformNoProof} from "src/pancakeswap/PlatformNoProof.sol";
import {AxelarExecutableClaimer} from "src/AxelarExecutableClaimer.sol";

abstract contract DeployPancakeNoProofXChain is Script {
    address internal constant DEPLOYER = 0x000755Fbe4A24d7478bfcFC1E561AfCE82d1ff62;
    address internal constant GAUGE_VOTING = 0xf81953dC234cdEf1D6D0d3ef61b232C6bCbF9aeF;
    address internal immutable axelarGateway;
    address internal constant BNB_STATE_SENDER = address(0);

    AxelarExecutableClaimer internal axelarExecutable;
    PlatformNoProof internal platform;

    constructor(address _axelarGateway) {
        axelarGateway = _axelarGateway;
    }

    function run() public virtual {
        vm.startBroadcast(DEPLOYER);

        axelarExecutable = new AxelarExecutableClaimer(axelarGateway, BNB_STATE_SENDER, "binance", address(0));

        platform = new PlatformNoProof(DEPLOYER, DEPLOYER, address(axelarExecutable));

        // Set Platform fees
        platform.setPlatformFee(40000000000000000); // 4%

        // set Platform in claimer
        platform.setBountyClaimer(address(axelarExecutable));

        // Asserts
        assert(platform.feeCollector() == DEPLOYER);
        assert(platform.owner() == DEPLOYER);

        vm.stopBroadcast();
    }
}
