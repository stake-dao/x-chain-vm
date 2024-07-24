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
import {FXNOracle} from "src/oracles/FXNOracle.sol";
import {BasePlatformTest} from "test/integration/BasePlatformTest.sol";

contract AxelarGateway {
    function validateContractCall(bytes32, string calldata, string calldata, bytes32) external pure returns (bool) {
        return true;
    }
}

contract FXNPlatformTest is BasePlatformTest {
    using LibString for string;
    using LibString for address;
    using stdStorage for StdStorage;

    function setUp() public override {
        blockNumber = 20178326; // Wednesday
        startPeriodBlockNumber = 20179427; // Thursday

        super.setUp();

        _user = 0x75736518075a01034fa72D675D36a47e9B06B2Fb;
        _user2 = 0xf3e0974A5fEcFE4173e454993406243B2188EeeD;
        _gauge = 0x61F32964C39Cca4353144A6DB2F8Efdb3216b35B;
        _blacklisted = 0xc40549aa1D05C30af23a1C4a5af6bA11FCAFe23F;
        _deployer = 0x0dE5199779b43E13B3Bec21e91117E18736BC1A8;

        _gaugeController = GaugeController(0xe60eB8098B34eD775ac44B1ddE864e098C6d7f37);

        sender = new EthereumStateSender(_deployer);

        oracles = new address[](2);
        oracles[0] = address(new FXNOracle(address(axelarExecutable), address(_gaugeController)));
        oracles[1] = address(new FXNOracle(address(axelarExecutable), address(_gaugeController)));

        axelarExecutable = new AxelarExecutable(address(_gateway), address(sender), oracles, "Ethereum");

        FXNOracle(oracles[0]).setAxelarExecutable(address(axelarExecutable));
        FXNOracle(oracles[1]).setAxelarExecutable(address(axelarExecutable));

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
