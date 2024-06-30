// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

import {BaseGaugeControllerOracle} from "./BaseGaugeControllerOracle.sol";
import {LibString} from "solady/utils/LibString.sol";
import {RLPReader} from "src/merkle-utils/RLPReader.sol";
import {StateProofVerifier as Verifier} from "src/merkle-utils/StateProofVerifier.sol";

contract BalancerOracle is BaseGaugeControllerOracle {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;
    using LibString for address;
    using LibString for string;

    constructor(address _axelarExecutable, address _gaugeController)
        BaseGaugeControllerOracle(_axelarExecutable, _gaugeController)
    {}

    function _extractProofState(address _user, address _gauge, bytes memory _block_header_rlp, bytes memory _proof_rlp)
        internal
        view
        override
        returns (
            Point memory weight,
            VotedSlope memory userSlope,
            uint256 lastVote,
            uint256 blockNumber,
            bytes32 stateRootHash
        )
    {
        Verifier.BlockHeader memory block_header = Verifier.parseBlockHeader(_block_header_rlp);
        blockNumber = block_header.number;

        if (block_header.hash == bytes32(0)) revert INVALID_HASH();
        if (block_header.hash != _eth_blockhash[blockNumber]) revert INVALID_HASH_MISMATCH(); // dev: blockhash mismatch

        // Convert _proof_rlp into a list of `RLPItem`s.
        RLPReader.RLPItem[] memory proofs = _proof_rlp.toRlpItem().toList();
        if (proofs.length < 7) revert INVALID_PROOF_LENGTH();

        stateRootHash = _state_root_hash[blockNumber];
        if (stateRootHash == bytes32(0)) {
            // 0th proof is the account proof for Gauge Controller contract
            Verifier.Account memory gauge_controller_account = Verifier.extractAccountFromProof(
                GAUGE_CONTROLLER_HASH, // position of the account is the hash of its address
                block_header.stateRootHash,
                proofs[0].toList()
            );
            if (!gauge_controller_account.exists) revert GAUGE_CONTROLLER_NOT_FOUND();
            stateRootHash = gauge_controller_account.storageRoot;
        }
        unchecked {
            /// User's account proof.
            /// Last User Vote.
            lastVote = Verifier.extractSlotValueFromProof(
                keccak256(abi.encode(uint256(keccak256(abi.encode(keccak256(abi.encode(1000000007, _user)), _gauge))))),
                stateRootHash,
                proofs[1].toList()
            ).value;

            userSlope.slope = Verifier.extractSlotValueFromProof(
                keccak256(
                    abi.encode(uint256(keccak256(abi.encode(keccak256(abi.encode(1000000005, _user)), _gauge))) + 0)
                ),
                stateRootHash,
                proofs[4].toList()
            ).value;

            userSlope.power = Verifier.extractSlotValueFromProof(
                keccak256(
                    abi.encode(uint256(keccak256(abi.encode(keccak256(abi.encode(1000000005, _user)), _gauge))) + 1)
                ),
                stateRootHash,
                proofs[5].toList()
            ).value;

            userSlope.end = Verifier.extractSlotValueFromProof(
                keccak256(
                    abi.encode(uint256(keccak256(abi.encode(keccak256(abi.encode(1000000005, _user)), _gauge))) + 2)
                ),
                stateRootHash,
                proofs[6].toList()
            ).value;

            weight = pointWeights[_gauge][blockNumber];
            if (weight.bias == 0) {
                /// Gauge Weight proof.
                uint256 time = (block_header.timestamp / 1 weeks) * 1 weeks;

                weight.bias = Verifier.extractSlotValueFromProof(
                    keccak256(
                        abi.encode(uint256(keccak256(abi.encode(keccak256(abi.encode(1000000008, _gauge)), time))) + 0)
                    ),
                    stateRootHash,
                    proofs[2].toList()
                ).value;

                weight.slope = Verifier.extractSlotValueFromProof(
                    keccak256(
                        abi.encode(uint256(keccak256(abi.encode(keccak256(abi.encode(1000000008, _gauge)), time))) + 1)
                    ),
                    stateRootHash,
                    proofs[3].toList()
                ).value;
            }
        }
    }
}
