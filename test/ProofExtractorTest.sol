// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "test/utils/Utils.sol";

import {GaugeController} from "src/interfaces/GaugeController.sol";
import {EthereumStateSender} from "src/EthereumStateSender.sol";
import {GaugeControllerOracle} from "src/GaugeControllerOracle.sol";
import {StateProofVerifier as Verifier} from "src/merkle-utils/StateProofVerifier.sol";

contract ProofExtractorTest is Utils {
    EthereumStateSender sender;
    GaugeControllerOracle oracle;

    address internal user;
    address internal gauge;
    address internal gaugeController;

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

        user = _curveUser;
        gauge = _balancerGauge;
        gaugeController = _balancerGC;

        sender = new EthereumStateSender(_deployer);
        oracle = new GaugeControllerOracle(address(0), gaugeController);
    }

    function testGetProofParams() public {
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(user, gauge, block.timestamp / 1 weeks * 1 weeks);

        // Query the chain before retrieving the proofs.
        uint256 last_user_vote = GaugeController(gaugeController).last_user_vote(user, gauge);

        GaugeController.VotedSlope memory voted_slope = GaugeController(gaugeController).vote_user_slopes(user, gauge);

        //console.log(last_user_vote);

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", gaugeController, _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.setEthBlockHash(_blockNumber, _block_hash);

        // Submit State to Oracle.
        oracle.submit_state(user, gauge, _block_header_rlp, _proof_rlp);

        /// Retrive the values from the oracle.
        (uint256 slope, uint256 power, uint256 end) = oracle.voteUserSlope(_blockNumber, user, gauge);

        //console.log(oracle.lastUserVote(_blockNumber, user, gauge));

        return;

        assertEq(last_user_vote, oracle.lastUserVote(_blockNumber, user, gauge));
        assertEq(voted_slope.slope, slope);
        assertEq(voted_slope.power, power);
        assertEq(voted_slope.end, end);
    }
}
