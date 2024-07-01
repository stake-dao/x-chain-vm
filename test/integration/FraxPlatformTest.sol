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
import {FraxOracle} from "src/oracles/FraxOracle.sol";
import {BasePlatformTest} from "test/integration/BasePlatformTest.sol";

contract AxelarGateway {
    function validateContractCall(bytes32, string calldata, string calldata, bytes32) external pure returns (bool) {
        return true;
    }
}

contract FraxPlatformTest is BasePlatformTest {
    using LibString for string;
    using LibString for address;
    using stdStorage for StdStorage;

    function setUp() public override {
        blockNumber = 20178326; // Wednesday
        startPeriodBlockNumber = 20179427; // Thursday

        super.setUp();

        _user = 0xCd3a267DE09196C48bbB1d9e842D7D7645cE448f;
        _user2 = 0x9c5083dd4838E120Dbeac44C052179692Aa5dAC5;
        _gauge = 0xB4fdD7444E1d86b2035c97124C46b1528802DA35;
        _blacklisted = 0x59CFCD384746ec3035299D90782Be065e466800B;
        _deployer = 0x0dE5199779b43E13B3Bec21e91117E18736BC1A8;

        _gaugeController = GaugeController(0x3669C421b77340B2979d1A00a792CC2ee0FcE737);

        sender = new EthereumStateSender(_deployer);

        oracles = new address[](2);
        oracles[0] = address(new FraxOracle(address(axelarExecutable), address(_gaugeController)));
        oracles[1] = address(new FraxOracle(address(axelarExecutable), address(_gaugeController)));

        axelarExecutable = new AxelarExecutable(address(_gateway), address(sender), oracles);

        FraxOracle(oracles[0]).setAxelarExecutable(address(axelarExecutable));
        FraxOracle(oracles[1]).setAxelarExecutable(address(axelarExecutable));

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
