// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import "test/utils/Utils.sol";
import "forge-std/Script.sol";

import {Platform} from "src/Platform.sol";
import {AxelarExecutable} from "src/AxelarExecutable.sol";
import {EthereumStateSender} from "src/EthereumStateSender.sol";
import {BalancerGaugeControllerOracle} from "src/balancer/BalancerGaugeControllerOracle.sol";

contract DeploySideChains is Script, Utils {
    /// Ethereum State Sender.
    address internal constant ETH_STATE_SENDER = 0xe742141075767106FeD9F6FFA99f07f33bd66312;

    /// Arbitrum Axelar Gateway.
    address internal constant _AXELAR_GATEWAY = 0xe432150cce91c13a887f7D836923d5597adD8E31;

    // LL
    address internal STAKE_LOCKER = 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6;

    Platform platform;
    BalancerGaugeControllerOracle oracle;
    AxelarExecutable axelarExecutable;

    address internal constant DEPLOYER = 0x8898502BA35AB64b3562aBC509Befb7Eb178D4df;

    function run() public {
        vm.startBroadcast(DEPLOYER);

        oracle = new BalancerGaugeControllerOracle(address(0));
        axelarExecutable = new AxelarExecutable(_AXELAR_GATEWAY, ETH_STATE_SENDER, address(oracle));
        oracle.setAxelarExecutable(address(axelarExecutable));

        platform = new Platform(address(oracle), DEPLOYER, DEPLOYER);

        // Whitelist Liquid Wrappers
        platform.whitelistAddress(STAKE_LOCKER, true);

        // Set Platform fees
        platform.setPlatformFee(40000000000000000); // 4%

        // Asserts
        assert(address(oracle.axelarExecutable()) == address(axelarExecutable));
        assert(address(platform.gaugeController()) == address(oracle));
        assert(platform.whitelisted(STAKE_LOCKER));

        vm.stopBroadcast();
    }
}