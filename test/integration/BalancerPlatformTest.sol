// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "test/utils/Utils.sol";

import {Platform} from "src/Platform.sol";
import {PlatformClaimable} from "src/PlatformClaimable.sol";
import {LibString} from "solady/utils/LibString.sol";
import {AxelarExecutable} from "src/AxelarExecutable.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {GaugeController} from "src/interfaces/GaugeController.sol";
import {EthereumStateSender} from "src/EthereumStateSender.sol";
import {BaseGaugeControllerOracle} from "src/oracles/BaseGaugeControllerOracle.sol";
import {BalancerOracle} from "src/oracles/BalancerOracle.sol";
import {BasePlatformTest} from "test/integration/BasePlatformTest.sol";

contract AxelarGateway {
    function validateContractCall(bytes32, string calldata, string calldata, bytes32) external pure returns (bool) {
        return true;
    }
}

contract BalancerPlatformTest is BasePlatformTest {
    using LibString for string;
    using LibString for address;
    using stdStorage for StdStorage;

    function setUp() public override {
        blockNumber = 20178326; // Wednesday
        startPeriodBlockNumber = 20179427; // Thursday

        super.setUp();

        _user = 0xea79d1A83Da6DB43a85942767C389fE0ACf336A5;
        _user2 = 0x9cC56Fa7734DA21aC88F6a816aF10C5b898596Ce;
        _gauge = 0xDc2Df969EE5E66236B950F5c4c5f8aBe62035df2;
        _blacklisted = 0x82a3b3274949C050952f8F826B099525f3A4572F;
        _deployer = 0x0dE5199779b43E13B3Bec21e91117E18736BC1A8;

        _gaugeController = GaugeController(0xC128468b7Ce63eA702C1f104D55A2566b13D3ABD);

        sender = new EthereumStateSender(_deployer);

        oracles = new address[](2);
        oracles[0] = address(new BalancerOracle(address(axelarExecutable), address(_gaugeController)));
        oracles[1] = address(new BalancerOracle(address(axelarExecutable), address(_gaugeController)));

        axelarExecutable = new AxelarExecutable(address(_gateway), address(sender), oracles, "Ethereum");

        BalancerOracle(oracles[0]).setAxelarExecutable(address(axelarExecutable));
        BalancerOracle(oracles[1]).setAxelarExecutable(address(axelarExecutable));

        platform = new Platform(address(oracles[0]), address(this), address(this));
        platformClaimable = new PlatformClaimable(address(oracles[0]));

        rewardToken.mint(address(this), _amount);
        rewardToken.approve(address(platform), _amount);
    }

    function encodeProofs(address gauge, address user)
        public
        override
        returns (bytes32 block_hash, bytes memory block_header_rlp, bytes memory proof_rlp)
    {
        (block_hash, block_header_rlp, proof_rlp) = getRLPEncodedProofsForGaugeController(
            "mainnet", address(_gaugeController), user, gauge, startPeriodBlockNumber, _getCurrentPeriod()
        );
    }
}
