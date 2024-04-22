// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "test/utils/Utils.sol";
import "forge-std/Script.sol";

import {MockPlatform} from "src/MockPlatform.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {CurveGaugeControllerOracle} from "src/CurveGaugeControllerOracle.sol";

contract DeploySideChains is Script, Utils {
    MockPlatform platform;
    MockERC20 mockToken;
    CurveGaugeControllerOracle oracle;

    address internal constant DEPLOYER = 0x8898502BA35AB64b3562aBC509Befb7Eb178D4df;

    function run() public {
        vm.startBroadcast(DEPLOYER);

        //oracle = new CurveGaugeControllerOracle(address(0));

        //platform = new MockPlatform(address(oracle), DEPLOYER, DEPLOYER);

        mockToken = new MockERC20("TestCrossBribes", "TCB", 18);

        mockToken.mint(address(this), 1000e18);
        mockToken.approve(address(platform), 1000e18);

        vm.stopBroadcast();
    }
}
