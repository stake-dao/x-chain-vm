// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "test/utils/Utils.sol";

import {GaugeController} from "src/interfaces/GaugeController.sol";
import {EthereumStateSender} from "src/EthereumStateSender.sol";
import {GaugeControllerOracle} from "src/GaugeControllerOracle.sol";

import {BalancerOracle} from "src/BalancerOracle.sol";
import {FraxOracle} from "src/FraxOracle.sol";

import {StateProofVerifier as Verifier} from "src/merkle-utils/StateProofVerifier.sol";

contract ProofExtractorTest is Utils {
    EthereumStateSender sender;
    BalancerOracle balancerOracle;
    FraxOracle fraxOracle;

    address internal constant _deployer = 0x0dE5199779b43E13B3Bec21e91117E18736BC1A8;

    // Balancer
    address internal _balancerUser = 0x04e8e5aA372D8e2233D2EF26079e23E3309003D5;
    address internal _balancerGauge = 0x2D02Bf5EA195dc09854E18E7d2857A16bF376963;
    address internal _balancerGC = 0xC128468b7Ce63eA702C1f104D55A2566b13D3ABD;

    // Frax
    address internal _fraxUser = 0xCd3a267DE09196C48bbB1d9e842D7D7645cE448f;
    address internal _fraxGauge = 0x68921998fbc43B360D3cF14a03aF4273CB0cFA44;
    address internal _fraxGC = 0x3669C421b77340B2979d1A00a792CC2ee0FcE737;

    // Curve
    address internal _curveUser = 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6;
    address internal _curveGauge = 0x16A3a047fC1D388d5846a73ACDb475b11228c299;
    address internal _curveGC = 0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB;

    function setUp() public {
        uint256 forkId = vm.createFork("https://eth.public-rpc.com", 20179427);
        vm.selectFork(forkId);

        balancerOracle = new BalancerOracle(address(0), _balancerGC);
        fraxOracle = new FraxOracle(address(0), _fraxGC);

        sender = new EthereumStateSender(_deployer);
    }

    function testGetProofParamsBalancer() public {
        // Query the chain before retrieving the proofs.
        uint256 last_user_vote = GaugeController(_balancerGC).last_user_vote(_balancerUser, _balancerGauge);
        GaugeController.VotedSlope memory voted_slope =
            GaugeController(_balancerGC).vote_user_slopes(_balancerUser, _balancerGauge);
        GaugeController.Point memory points_weight =
            GaugeController(_balancerGC).points_weight(_balancerGauge, block.timestamp / 1 weeks * 1 weeks);

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
        getRLPEncodedProofsForGaugeController(
            "mainnet", _balancerGC, _balancerUser, _balancerGauge, block.number, block.timestamp / 1 weeks * 1 weeks
        );

        // Submit ETH Block Hash to Oracle.
        balancerOracle.setEthBlockHash(block.number, _block_hash);

        // Submit State to Oracle.
        balancerOracle.submit_state(_balancerUser, _balancerGauge, _block_header_rlp, _proof_rlp);

        /// Retrive the values from the oracle.
        (uint256 slope, uint256 power, uint256 end) =
            balancerOracle.voteUserSlope(block.number, _balancerUser, _balancerGauge);

        assertEq(last_user_vote, balancerOracle.lastUserVote(block.number, _balancerUser, _balancerGauge));

        (uint256 weight_bias, uint256 weight_slope) = balancerOracle.pointWeights(_balancerGauge, block.number);

        assertEq(weight_bias, points_weight.bias);
        assertEq(weight_slope, points_weight.slope);

        assertEq(voted_slope.slope, slope);
        assertEq(voted_slope.power, power);
        assertEq(voted_slope.end, end);
    }

    function testGetProofParamsFrax() public {
        // Query the chain before retrieving the proofs.
        uint256 last_user_vote = GaugeController(_fraxGC).last_user_vote(_fraxUser, _fraxGauge);
        GaugeController.VotedSlope memory voted_slope = GaugeController(_fraxGC).vote_user_slopes(_fraxUser, _fraxGauge);
        GaugeController.Point memory points_weight =
            GaugeController(_fraxGC).points_weight(_fraxGauge, block.timestamp / 1 weeks * 1 weeks);

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
        getRLPEncodedProofsForGaugeController(
            "mainnet", _fraxGC, _fraxUser, _fraxGauge, block.number, block.timestamp / 1 weeks * 1 weeks
        );

        // Submit ETH Block Hash to Oracle.
        fraxOracle.setEthBlockHash(block.number, _block_hash);

        // Submit State to Oracle.
        fraxOracle.submit_state(_fraxUser, _fraxGauge, _block_header_rlp, _proof_rlp);

        console.log("voted_slope.slope", voted_slope.slope);
        console.log("voted_slope.power", voted_slope.power);
        console.log("voted_slope.end", voted_slope.end);

        console.log("voted_weight.bias", points_weight.bias);
        console.log("voted_weight.slope", points_weight.slope);

        /*
        /// Retrive the values from the oracle.
        (uint256 slope, uint256 power, uint256 end) =
            fraxOracle.voteUserSlope(block.number, _fraxUser, _fraxGauge);

        assertEq(last_user_vote, fraxOracle.lastUserVote(block.number, _fraxUser, _fraxGauge));

        (uint256 weight_bias, uint256 weight_slope) = fraxOracle.pointWeights(_fraxGauge, block.number);

        assertEq(weight_bias, points_weight.bias);
        assertEq(weight_slope, points_weight.slope);

        assertEq(voted_slope.slope, slope);
        assertEq(voted_slope.power, power);
        assertEq(voted_slope.end, end);
        */
    }
}
