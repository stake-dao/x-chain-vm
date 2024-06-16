// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import "test/utils/Utils.sol";
import "forge-std/Script.sol";

import {AxelarExecutable} from "src/AxelarExecutable.sol";

contract DeployAxelarExecutableMulti is Script, Utils {
    address internal constant DEPLOYER = 0x8898502BA35AB64b3562aBC509Befb7Eb178D4df;
    address internal constant ETH_STATE_SENDER = 0xe742141075767106FeD9F6FFA99f07f33bd66312;

    address internal constant _AXELAR_GATEWAY = 0xe432150cce91c13a887f7D836923d5597adD8E31;

    // Deployed Oracles

    address CURVE_ORACLE = 0x9ED11340850DA2DEeeE3B471b335dA90272B066F;
    address BALANCER_ORACLE = 0x575b26EcF33169a394ed654EeCB141497e29bDF3;
    address FRAX_ORACLE = 0xb409a2F7840acfCd3a17B27eC045F80d6f10Eff2;
    address FXN_ORACLE = 0x560306228f913cB4e7A23d11716e8198Cb2c29b5;

    address[] oracles = [CURVE_ORACLE, BALANCER_ORACLE, FRAX_ORACLE, FXN_ORACLE];

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        AxelarExecutable axelarExecutable = new AxelarExecutable(_AXELAR_GATEWAY, ETH_STATE_SENDER, oracles);

        address oracleA = axelarExecutable.oracles(0);
        address oracleB = axelarExecutable.oracles(1);
        address oracleC = axelarExecutable.oracles(2);
        address oracleD = axelarExecutable.oracles(3);

        assertEq(oracleA, CURVE_ORACLE);
        assertEq(oracleB, BALANCER_ORACLE);
        assertEq(oracleC, FRAX_ORACLE);
        assertEq(oracleD, FXN_ORACLE);

        // NEED TO SET AXELAR EXECUTABLE (new one) in each oracle contract

        vm.stopBroadcast();
    }
}
