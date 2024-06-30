// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import "test/utils/Utils.sol";
import "forge-std/Script.sol";

import {Platform} from "src/Platform.sol";
import {AxelarExecutable} from "src/AxelarExecutable.sol";
import {CurveOracle} from "src/oracles/CurveOracle.sol";

abstract contract DeployMulti is Script, Utils {
    address internal constant DEPLOYER = 0x8898502BA35AB64b3562aBC509Befb7Eb178D4df;
    address internal constant ETH_STATE_SENDER = 0xe742141075767106FeD9F6FFA99f07f33bd66312;

    address internal constant _AXELAR_GATEWAY = 0xe432150cce91c13a887f7D836923d5597adD8E31;

    // GAUGES 
    address internal constant CURVE_GAUGE_CONTROLLER = 0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB;
    address internal constant BALANCER_GAUGE_CONTROLLER = 0xC128468b7Ce63eA702C1f104D55A2566b13D3ABD;
    address internal constant FRAX_GAUGE_CONTROLLER = 0x3669C421b77340B2979d1A00a792CC2ee0FcE737;
    address internal constant FXN_GAUGE_CONTROLLER = 0xe60eB8098B34eD775ac44B1ddE864e098C6d7f37;

    // LL
    address internal STAKE_LOCKER = 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6;

    function run() public virtual {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        // Deploy oracles for Curve, Balancer, Frax, FXN
        CurveOracle curve_oracle = new CurveOracle(address(0), CURVE_GAUGE_CONTROLLER);
        CurveOracle balancer_oracle = new CurveOracle(address(0), BALANCER_GAUGE_CONTROLLER);
        CurveOracle frax_oracle = new CurveOracle(address(0), FRAX_GAUGE_CONTROLLER);
        CurveOracle fxn_oracle = new CurveOracle(address(0), FXN_GAUGE_CONTROLLER);

        address[] memory oracles = new address[](4);
        oracles[0] = address(curve_oracle);
        oracles[1] = address(balancer_oracle);
        oracles[2] = address(frax_oracle);
        oracles[3] = address(fxn_oracle);

        AxelarExecutable axelarExecutable = new AxelarExecutable(_AXELAR_GATEWAY, ETH_STATE_SENDER, oracles);

        curve_oracle.setAxelarExecutable(address(axelarExecutable));
        balancer_oracle.setAxelarExecutable(address(axelarExecutable));
        frax_oracle.setAxelarExecutable(address(axelarExecutable));
        fxn_oracle.setAxelarExecutable(address(axelarExecutable));

        // Deploy Platforms
        Platform curve_platform = new Platform(address(curve_oracle), DEPLOYER, DEPLOYER);
        Platform balancer_platform = new Platform(address(balancer_oracle), DEPLOYER, DEPLOYER);
        Platform frax_platform = new Platform(address(frax_oracle), DEPLOYER, DEPLOYER);
        Platform fxn_platform = new Platform(address(fxn_oracle), DEPLOYER, DEPLOYER);


        // Whitelist Liquid Wrappers
        curve_platform.whitelistAddress(STAKE_LOCKER, true);
        balancer_platform.whitelistAddress(STAKE_LOCKER, true);
        frax_platform.whitelistAddress(STAKE_LOCKER, true);
        fxn_platform.whitelistAddress(STAKE_LOCKER, true);

        // Set Platform fees
        curve_platform.setPlatformFee(40000000000000000); // 4%
        balancer_platform.setPlatformFee(40000000000000000); // 4%
        frax_platform.setPlatformFee(40000000000000000); // 4%
        fxn_platform.setPlatformFee(40000000000000000); // 4%

        address oracleA = axelarExecutable.oracles(0);
        address oracleB = axelarExecutable.oracles(1);
        address oracleC = axelarExecutable.oracles(2);
        address oracleD = axelarExecutable.oracles(3);

        // Asserts
        assertEq(oracleA, address(curve_oracle));
        assertEq(oracleB, address(balancer_oracle));
        assertEq(oracleC, address(frax_oracle));
        assertEq(oracleD, address(fxn_oracle));

        assertEq(address(curve_oracle.axelarExecutable()), address(axelarExecutable));
        assertEq(address(balancer_oracle.axelarExecutable()), address(axelarExecutable));
        assertEq(address(frax_oracle.axelarExecutable()), address(axelarExecutable));
        assertEq(address(fxn_oracle.axelarExecutable()), address(axelarExecutable));
        
        console.log("Axelar Executable:", address(axelarExecutable));

        console.log("Deployed Platforms:");
        console.log("Curve:", address(curve_platform));
        console.log("Balancer:", address(balancer_platform));
        console.log("Frax:", address(frax_platform));
        console.log("FXN:", address(fxn_platform));

        console.log("Deployed Oracles:");
        console.log("Curve:", address(curve_oracle));
        console.log("Balancer:", address(balancer_oracle));
        console.log("Frax:", address(frax_oracle));
        console.log("FXN:", address(fxn_oracle));

        vm.stopBroadcast();
    }
}
