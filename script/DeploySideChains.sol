// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import "test/utils/Utils.sol";
import "forge-std/Script.sol";

import {Platform} from "src/Platform.sol";
import {AxelarExecutable} from "src/AxelarExecutable.sol";
import {EthereumStateSender} from "src/EthereumStateSender.sol";
import {CurveGaugeControllerOracle} from "src/CurveGaugeControllerOracle.sol";
import {StateProofVerifier as Verifier} from "src/merkle-utils/StateProofVerifier.sol";

contract DeploySideChains is Script, Utils {
    /// Ethereum State Sender.
    address internal constant ETH_STATE_SENDER = 0xC19d317c84e43F93fFeBa146f4f116A6F2B04663;

    /// Arbitrum Axelar Gateway.
    address internal constant _AXELAR_GATEWAY = 0xe432150cce91c13a887f7D836923d5597adD8E31;

    // LL
    address internal STAKE_LOCKER = 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6;
    address internal YEARN_LOCKER = 0xF147b8125d2ef93FB6965Db97D6746952a133934;
    address internal CONVEX_LOCKER = 0x989AEb4d175e16225E39E87d0D97A3360524AD80;

    Platform platform;
    CurveGaugeControllerOracle oracle;
    AxelarExecutable axelarExecutable;

    address internal constant DEPLOYER = 0x8898502BA35AB64b3562aBC509Befb7Eb178D4df;

    function run() public {
        vm.startBroadcast(DEPLOYER);

        oracle = new CurveGaugeControllerOracle(address(0));
        axelarExecutable = new AxelarExecutable(_AXELAR_GATEWAY, ETH_STATE_SENDER, address(oracle));
        oracle.setAxelarExecutable(address(axelarExecutable));

        platform = new Platform(address(oracle), DEPLOYER, DEPLOYER);

        // Whitelist Liquid Wrappers
        platform.whitelistAddress(STAKE_LOCKER, true);
        platform.whitelistAddress(YEARN_LOCKER, true);
        platform.whitelistAddress(CONVEX_LOCKER, true);

        // Set Platform fees
        platform.setPlatformFee(40000000000000000); // 4%

        // Asserts
        assert(address(oracle.axelarExecutable()) == address(axelarExecutable));
        assert(address(platform.gaugeController()) == address(oracle));
        assert(platform.whitelisted(STAKE_LOCKER));
        assert(platform.whitelisted(YEARN_LOCKER));
        assert(platform.whitelisted(CONVEX_LOCKER));

        vm.stopBroadcast();
    }
}
