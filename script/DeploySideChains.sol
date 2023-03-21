// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {Platform} from "src/Platform.sol";
import {AxelarExecutable} from "src/AxelarExecutable.sol";
import {CurveGaugeControllerOracle} from "src/CurveGaugeControllerOracle.sol";

contract DeploySideChains is Script {
    /// Ethereum State Sender.
    address internal constant ETH_STATE_SENDER = 0xC19d317c84e43F93fFeBa146f4f116A6F2B04663;

    /// Arbitrum Axelar Gateway.
    address internal constant _AXELAR_GATEWAY = 0xe432150cce91c13a887f7D836923d5597adD8E31;

    Platform platform;
    CurveGaugeControllerOracle oracle;
    AxelarExecutable axelarExecutable;

    address internal constant DEPLOYER = 0x0dE5199779b43E13B3Bec21e91117E18736BC1A8;

    function run() public {
        vm.startBroadcast(DEPLOYER);

        oracle = new CurveGaugeControllerOracle(address(0));
        axelarExecutable = new AxelarExecutable(_AXELAR_GATEWAY, ETH_STATE_SENDER, address(oracle));
        oracle.setAxelarExecutable(address(axelarExecutable));

        platform = new Platform(address(oracle), DEPLOYER, DEPLOYER);

        vm.stopBroadcast();
    }
}
