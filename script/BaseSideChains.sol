// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "test/utils/Utils.sol";
import "forge-std/Script.sol";

import {Platform} from "src/Platform.sol";
import {AxelarExecutable} from "src/AxelarExecutable.sol";
import {EthereumStateSender} from "src/EthereumStateSender.sol";
import {CurveOracle} from "src/oracles/CurveOracle.sol";

abstract contract BaseSideChains is Script, Utils {
    /// Ethereum State Sender.
    address internal constant ETH_STATE_SENDER = 0xe742141075767106FeD9F6FFA99f07f33bd66312;

    /// Arbitrum Axelar Gateway.
    address internal constant _AXELAR_GATEWAY = 0xe432150cce91c13a887f7D836923d5597adD8E31;

    // LL
    address internal STAKE_LOCKER = 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6;

    Platform platform;
    CurveOracle oracle;
    AxelarExecutable axelarExecutable;

    address internal constant DEPLOYER = 0x000755Fbe4A24d7478bfcFC1E561AfCE82d1ff62;

    address public immutable gaugeController;

    constructor(address _gaugeController) {
        gaugeController = _gaugeController;
    }

    function run() public {
        vm.startBroadcast(DEPLOYER);

        oracle = new CurveOracle(address(0), gaugeController);

        address[] memory oracles = new address[](1);
        oracles[0] = address(oracle);

        axelarExecutable = new AxelarExecutable(_AXELAR_GATEWAY, ETH_STATE_SENDER, oracles, "Ethereum");
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
