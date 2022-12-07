// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "test/utils/Utils.sol";

import {GaugeController} from "src/interfaces/GaugeController.sol";
import {EthereumStateSender} from "src/merkle-utils/EthereumStateSender.sol";
import {CurveGaugeControllerOracle} from "src/CurveGaugeControllerOracle.sol";

contract ProofExtractor is Utils {
    EthereumStateSender sender;
    CurveGaugeControllerOracle oracle;

    address internal constant _user = 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6;
    address internal constant _gauge = 0xd8b712d29381748dB89c36BCa0138d7c75866ddF;
    // Gauge Controller
    address internal constant _gaugeController = 0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB;

    function setUp() public {
        sender = new EthereumStateSender();
        oracle = new CurveGaugeControllerOracle(address(0));
    }

    function testGetProofParams() public {
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, block.timestamp / 1 weeks * 1 weeks);

        // Query the chain before retrieving the proofs.
        uint256 last_user_vote = GaugeController(_gaugeController).last_user_vote(_user, _gauge);
        GaugeController.VotedSlope memory voted_slope =
            GaugeController(_gaugeController).vote_user_slopes(_user, _gauge);

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", _gaugeController, _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.setEthBlockHash(_blockNumber, _block_hash);

        // Submit State to Oracle.
        oracle.submit_state(_user, _gauge, _block_header_rlp, _proof_rlp);

        /// Retrive the values from the oracle.
        (uint256 slope, uint256 power, uint256 end) = oracle.voteUserSlope(_blockNumber, _user, _gauge);

        assertEq(last_user_vote, oracle.lastUserVote(_blockNumber, _user, _gauge));
        assertEq(voted_slope.slope, slope);
        assertEq(voted_slope.power, power);
        assertEq(voted_slope.end, end);
    }
}
