// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

import {BaseGaugeControllerOracle} from "./BaseGaugeControllerOracle.sol";
import {LibString} from "solady/utils/LibString.sol";
import {RLPReader} from "src/merkle-utils/RLPReader.sol";
import {StateProofVerifier as Verifier} from "src/merkle-utils/StateProofVerifier.sol";

contract PancakeOracle is BaseGaugeControllerOracle {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;
    using LibString for address;
    using LibString for string;

    address public constant VE_CAKE = 0x5692DB8177a81A6c6afc8084C2976C9933EC1bAB;
    bytes32 public immutable VE_CAKE_HASH = keccak256(abi.encodePacked(VE_CAKE));

    mapping(address => address) public veCakeProxies;

    error VE_CAKE_NOT_FOUND();
    error WRONG_VECAKE_PROXY();

    constructor(address _axelarExecutable, address _gaugeController)
        BaseGaugeControllerOracle(_axelarExecutable, _gaugeController)
    {}

    function submit_state(address _user, address _gauge, bytes memory block_header_rlp_, bytes memory _user_proof_rlp)
        external
        override
    {}

    function submit_state(
        address _user,
        address _gauge,
        uint256 _chainId,
        bytes memory block_header_rlp_,
        bytes memory _user_proof_rlp
    ) external {
        _submit_state(_user, _gauge, _chainId, block_header_rlp_, _user_proof_rlp);
    }

    function submit_state(
        address _user,
        address _gauge,
        uint256 _chainId,
        bytes memory block_header_rlp_,
        bytes memory _user_proof_rlp,
        bytes memory _proxy_proof_rlp,
        bytes memory _proxy_owner_proof_rlp
    ) external {
        _submit_state(_user, _gauge, _chainId, block_header_rlp_, _user_proof_rlp);

        if (_proxy_proof_rlp.length > 0) {
            if (veCakeProxies[_user] == address(0)) {
                // check the proxy ownership
                (veCakeProxies[_user],,) = _extractVeCakeProofState(_user, block_header_rlp_, _proxy_owner_proof_rlp);
            }
            _submit_state(veCakeProxies[_user], _gauge, _chainId, block_header_rlp_, _proxy_proof_rlp);
        }
    }

    function _submit_state(
        address _user,
        address _gauge,
        uint256 _chainId,
        bytes memory block_header_rlp_,
        bytes memory _proof_rlp
    ) internal {
        // If not set for the last block number, set it
        if (block_header_rlp[last_eth_block_number].length == 0) {
            if (block_header_rlp_.length == 0) revert INVALID_BLOCK_HEADER();
            block_header_rlp[last_eth_block_number] = block_header_rlp_;
        }

        bytes memory _block_header_rlp = block_header_rlp[last_eth_block_number];

        // Verify the state proof
        (Point memory point, VotedSlope memory votedSlope, uint256 lastVote, uint256 blockNumber, bytes32 stateRootHash)
        = _extractProofState(_user, _gauge, _chainId, _block_header_rlp, _proof_rlp);

        pointWeights[_gauge][blockNumber] = point;
        voteUserSlope[blockNumber][_user][_gauge] = votedSlope;
        lastUserVote[blockNumber][_user][_gauge] = lastVote;
        isUserUpdated[blockNumber][_user][_gauge] = true;

        _state_root_hash[blockNumber] = stateRootHash;
    }

    function extractVeCakeProofState(address _user, bytes memory _block_header_rlp, bytes memory _proof_rlp)
        external
        view
    {
        _extractVeCakeProofState(_user, _block_header_rlp, _proof_rlp);
    }

    function _extractVeCakeProofState(address _user, bytes memory _block_header_rlp, bytes memory _proof_rlp)
        internal
        view
        returns (address proxy, uint256 blockNumber, bytes32 stateRootHash)
    {
        Verifier.BlockHeader memory block_header = Verifier.parseBlockHeader(_block_header_rlp);
        blockNumber = block_header.number;

        // Convert _proof_rlp into a list of `RLPItem`s.
        RLPReader.RLPItem[] memory proofs = _proof_rlp.toRlpItem().toList();
        if (proofs.length < 2) revert INVALID_PROOF_LENGTH();

        stateRootHash = _state_root_hash[blockNumber];
        if (stateRootHash == bytes32(0)) {
            // 0th proof is the account proof for Gauge Controller contract
            Verifier.Account memory ve_cake_account = Verifier.extractAccountFromProof(
                VE_CAKE_HASH, // position of the account is the hash of its address
                block_header.stateRootHash,
                proofs[0].toList()
            );
            if (!ve_cake_account.exists) revert VE_CAKE_NOT_FOUND();
            stateRootHash = ve_cake_account.storageRoot;
        }

        unchecked {
            // user's veCake proxy
            proxy = address(
                uint160(
                    Verifier.extractSlotValueFromProof(
                        keccak256(abi.encode(uint256(keccak256(abi.encode(_user, 10))) + 0)),
                        stateRootHash,
                        proofs[1].toList()
                    ).value
                )
            );
        }
    }

    function extractProofState(
        address _user,
        address _gauge,
        uint256 _chainId,
        bytes memory _block_header_rlp,
        bytes memory _proof_rlp
    )
        external
        view
        returns (
            Point memory weight,
            VotedSlope memory userSlope,
            uint256 lastVote,
            uint256 blockNumber,
            bytes32 stateRootHash
        )
    {
        // Use cached block header RLP if available
        if (block_header_rlp[last_eth_block_number].length > 0) {
            _block_header_rlp = block_header_rlp[last_eth_block_number];
        }
        return _extractProofState(_user, _gauge, _chainId, _block_header_rlp, _proof_rlp);
    }

    function _extractProofState(
        address _user,
        address _gauge,
        uint256 _chainId,
        bytes memory _block_header_rlp,
        bytes memory _proof_rlp
    )
        internal
        view
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
        if (proofs.length != 7) revert INVALID_PROOF_LENGTH();

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
            // use gauge hash
            bytes32 gaugeHash = keccak256(abi.encodePacked(_gauge, _chainId));
            /// User's account proof.
            /// Last User Vote.
            lastVote = Verifier.extractSlotValueFromProof(
                keccak256(
                    abi.encode(uint256(keccak256(abi.encode(gaugeHash, keccak256(abi.encode(_user, 6000000011))))))
                ),
                stateRootHash,
                proofs[1].toList()
            ).value;

            userSlope.slope = Verifier.extractSlotValueFromProof(
                keccak256(
                    abi.encode(uint256(keccak256(abi.encode(gaugeHash, keccak256(abi.encode(_user, 6000000009))))) + 0)
                ),
                stateRootHash,
                proofs[4].toList()
            ).value;

            userSlope.power = Verifier.extractSlotValueFromProof(
                keccak256(
                    abi.encode(uint256(keccak256(abi.encode(gaugeHash, keccak256(abi.encode(_user, 6000000009))))) + 1)
                ),
                stateRootHash,
                proofs[5].toList()
            ).value;

            userSlope.end = Verifier.extractSlotValueFromProof(
                keccak256(
                    abi.encode(uint256(keccak256(abi.encode(gaugeHash, keccak256(abi.encode(_user, 6000000009))))) + 2)
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
                        abi.encode(
                            uint256(keccak256(abi.encode(time, keccak256(abi.encode(gaugeHash, 6000000014))))) + 0
                        )
                    ),
                    stateRootHash,
                    proofs[2].toList()
                ).value;

                weight.slope = Verifier.extractSlotValueFromProof(
                    keccak256(
                        abi.encode(
                            uint256(keccak256(abi.encode(time, keccak256(abi.encode(gaugeHash, 6000000014))))) + 1
                        )
                    ),
                    stateRootHash,
                    proofs[3].toList()
                ).value;
            }
        }
    }
}
