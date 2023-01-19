// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import {Platform} from "src/Platform.sol";
import {CurveGaugeControllerOracle} from "src/CurveGaugeControllerOracle.sol";

contract DeploySideChains is Script {
    /// Ethereum State Sender.
    address internal constant ETH_STATE_SENDER = 0x0000000000000000000000000000000000000000;

    /// Arbitrum Axelar Gateway.
    address internal constant _ANYCALL = 0x37414a8662bC1D25be3ee51Fb27C2686e2490A89;

    Platform platform;
    CurveGaugeControllerOracle oracle;

    function run() public {
        vm.startBroadcast();

        oracle = new CurveGaugeControllerOracle(_ANYCALL);
        platform = new Platform(address(oracle));

        vm.stopBroadcast();
    }
}
