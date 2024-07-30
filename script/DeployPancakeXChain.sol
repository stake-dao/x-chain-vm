// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

import {Platform} from "src/pancakeswap/Platform.sol";
import {AxelarExecutable} from "src/AxelarExecutable.sol";
import {BnbStateSender} from "src/BnbStateSender.sol";
import {PancakeOracle} from "src/oracles/PancakeOracle.sol";

abstract contract DeployPancakeXChain is Script {
    address internal constant DEPLOYER = 0x000755Fbe4A24d7478bfcFC1E561AfCE82d1ff62;
    address internal constant GAUGE_VOTING = 0xf81953dC234cdEf1D6D0d3ef61b232C6bCbF9aeF;
    address internal immutable axelarGateway;
    address internal constant BNB_STATE_SENDER = address(0); // TO CHANGE before run the script

    PancakeOracle internal oracle;
    AxelarExecutable internal axelarExecutable;
    Platform internal platform;

    constructor(address _axelarGateway) {
        axelarGateway = _axelarGateway;
    }

    function run() public virtual {
        vm.startBroadcast(DEPLOYER);

        oracle = new PancakeOracle(address(0), GAUGE_VOTING);

        address[] memory oracles = new address[](1);
        oracles[0] = address(oracle);

        axelarExecutable = new AxelarExecutable(axelarGateway, BNB_STATE_SENDER, oracles, "Bsc");
        oracle.setAxelarExecutable(address(axelarExecutable));

        platform = new Platform(address(oracle), DEPLOYER, DEPLOYER);

        // Set Platform fees
        platform.setPlatformFee(40000000000000000); // 4%

        // Asserts
        assert(address(oracle.axelarExecutable()) == address(axelarExecutable));
        assert(address(platform.gaugeController()) == address(oracle));

        vm.stopBroadcast();
    }
}
