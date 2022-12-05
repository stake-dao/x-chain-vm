// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "test/utils/Utils.sol";

import {Platform} from "src/Platform.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {GaugeController} from "src/interfaces/GaugeController.sol";
import {EthereumStateSender} from "src/merkle-utils/EthereumStateSender.sol";
import {CurveGaugeControllerOracle} from "src/CurveGaugeControllerOracle.sol";

contract PlatformXChainTest is Utils {
    EthereumStateSender sender;
    CurveGaugeControllerOracle oracle;

    // Main Platform Contract
    Platform internal platform;

    // Bribe Token.
    MockERC20 rewardToken = new MockERC20("Token", "TKO", 18);

    address internal constant _user = 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6;
    address internal constant _gauge = 0xd8b712d29381748dB89c36BCa0138d7c75866ddF;
    // Gauge Controller
    GaugeController internal constant _gaugeController = GaugeController(0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB);

    uint256 internal constant _amount = 10_000e18;

    function setUp() public {
        sender = new EthereumStateSender();
        oracle = new CurveGaugeControllerOracle(address(0));

        platform = new Platform(address(oracle));

        rewardToken.mint(address(this), _amount);
        rewardToken.approve(address(platform), _amount);
    }

    function testCorrectAssertions() public {
        // Create Default Bribe.
        uint256 _id = _createDefaultBribe();
        _gaugeController.checkpoint_gauge(_gauge);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, block.timestamp / 1 weeks * 1 weeks);

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.setEthBlockHash(_blockNumber, _block_hash);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: _block_header_rlp,
            userProofRlp: _proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        platform.claim(_id, _proofData);

        /// TODO:
        /// Need to figure out how to test with Anvil by moving the block forward, and then eth_getProof.
    }

    function _createCustomBribe(
        address _gauge,
        address _rewardToken,
        uint8 _numberOfPeriods,
        uint256 _maxRewardPerVote,
        uint256,
        address[] memory _blacklist,
        bool upgradeable
    ) internal returns (uint256) {
        return platform.createBribe(
            _gauge, _user, address(_rewardToken), _numberOfPeriods, _maxRewardPerVote, _amount, _blacklist, upgradeable
        );
    }

    function _createDefaultBribe() internal returns (uint256) {
        return platform.createBribe(_gauge, _user, address(rewardToken), 2, 2e18, _amount, new address[](0), true);
    }
}
