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
import {CurveOracle} from "src/oracles/CurveOracle.sol";
import {BasePlatformTest} from "test/integration/BasePlatformTest.sol";

contract AxelarGateway {
    function validateContractCall(bytes32, string calldata, string calldata, bytes32) external pure returns (bool) {
        return true;
    }
}

contract CurvePlatformTest is BasePlatformTest {
    using LibString for string;
    using LibString for address;
    using stdStorage for StdStorage;

    function setUp() public override {
        blockNumber = 19728000; // Wednesday
        startPeriodBlockNumber = 19730772; // Thursday

        super.setUp();

        _user = 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6;
        _user2 = 0x2c268cBcB2A0AD4701B359373E138E3f7387Ba2B;
        _gauge = 0x26F7786de3E6D9Bd37Fcf47BE6F2bC455a21b74A;
        _blacklisted = 0xecdED8b1c603cF21299835f1DFBE37f10F2a29Af;
        _deployer = 0x0dE5199779b43E13B3Bec21e91117E18736BC1A8;

        _gaugeController = GaugeController(0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB);

        sender = new EthereumStateSender(_deployer);

        oracles = new address[](2);
        oracles[0] = address(new CurveOracle(address(axelarExecutable), address(_gaugeController)));
        oracles[1] = address(new CurveOracle(address(axelarExecutable), address(_gaugeController)));

        axelarExecutable = new AxelarExecutable(address(_gateway), address(sender), oracles);

        CurveOracle(oracles[0]).setAxelarExecutable(address(axelarExecutable));
        CurveOracle(oracles[1]).setAxelarExecutable(address(axelarExecutable));

        platform = new Platform(address(oracles[0]), address(this), address(this));
        platformClaimable = new PlatformClaimable(address(oracles[0]));

        rewardToken.mint(address(this), _amount);
        rewardToken.approve(address(platform), _amount);
    }

    function encodeProofs(address gauge, address user)
        public
        override
        returns (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp)
    {
        // Build the proof.
        (,,, uint256[6] memory _positions,) = sender.generateEthProofParams(user, gauge, _getCurrentPeriod());

        // Get RLP Encoded proofs.
        (_block_hash, _block_header_rlp, _proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, startPeriodBlockNumber);
    }
}
