// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {RLPReader} from "src/merkle-utils/RLPReader.sol";
import {IAnyCallProxy} from "src/interfaces/IAnyCallProxy.sol";
import {StateProofVerifier as Verifier} from "src/merkle-utils/StateProofVerifier.sol";

contract CurveGaugeControllerOracle {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    struct Point {
        uint256 bias;
        uint256 slope;
    }

    struct VotedSlope {
        uint256 slope;
        uint256 power;
        uint256 end;
    }

    address constant GAUGE_CONTROLLER = 0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB;
    bytes32 constant GAUGE_CONTROLLER_HASH = keccak256(abi.encodePacked(GAUGE_CONTROLLER));
    bytes32 constant GENESIS_BLOCKHASH = 0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3;

    error INVALID_HASH();
    error INVALID_BLOCK_HEADER();
    error INVALID_HASH_MISMATCH();
    error INVALID_PROOF_LENGTH();
    error GAUGE_CONTROLLER_NOT_FOUND();

    /// Address of the AnyCallProxy for the chain this contract is deployed on
    address public ANYCALL;

    /// Mapping of Ethereum block number to blockhash
    mapping(uint256 => bytes32) private _eth_blockhash;

    /// Mapping of Ethereum block number to blockhash
    mapping(uint256 => bytes32) private _state_root_hash;

    /// Last Ethereum block number which had its blockhash stored
    uint256 public last_eth_block_number;

    /// Owner of the contract with special privileges
    address public owner;

    mapping(address => mapping(uint256 => Point)) public pointWeights; // gauge => block => Point
    mapping(uint256 => mapping(address => mapping(address => VotedSlope))) public voteUserSlopes; // block -> user -> gauge -> VotedSlope
    mapping(uint256 => mapping(address => mapping(address => uint256))) public lastUserVote; // block -> user -> gauge -> lastUserVote
    mapping(uint256 => mapping(address => mapping(address => bool))) public userUpdated; // block -> user -> gauge -> bool
    /// Log a blockhash update

    event SetBlockhash(uint256 _eth_block_number, bytes32 _eth_blockhash);

    constructor(address _anyCall) {
        _eth_blockhash[0] = GENESIS_BLOCKHASH;
        emit SetBlockhash(0, GENESIS_BLOCKHASH);
        owner = msg.sender;

        ANYCALL = _anyCall;
    }

    function submit_state(address _user, address _gauge, bytes memory _block_header_rlp, bytes memory _proof_rlp)
        external
    {
        // Verify the state proof
        (Point memory point, VotedSlope memory votedSlope, uint256 lastVote, uint256 blockNumber, bytes32 stateRootHash)
        = _extractProofState(_user, _gauge, _block_header_rlp, _proof_rlp);

        pointWeights[_gauge][blockNumber] = point;
        voteUserSlopes[blockNumber][_user][_gauge] = votedSlope;
        lastUserVote[blockNumber][_user][_gauge] = lastVote;
        userUpdated[blockNumber][_user][_gauge] = true;

        _state_root_hash[blockNumber] = stateRootHash;
    }

    function extractProofState(address _user, address _gauge, bytes memory _block_header_rlp, bytes memory _proof_rlp)
        external
        view
        returns (
            Point memory point,
            VotedSlope memory votedSlope,
            uint256 lastVote,
            uint256 blockNumber,
            bytes32 stateRootHash
        )
    {
        return _extractProofState(_user, _gauge, _block_header_rlp, _proof_rlp);
    }

    function _extractProofState(address _user, address _gauge, bytes memory _block_header_rlp, bytes memory _proof_rlp)
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

        /// User's account proof.
        /// Last User Vote.
        lastVote = Verifier.extractSlotValueFromProof(
            keccak256(abi.encode(uint256(keccak256(abi.encode(keccak256(abi.encode(11, _user)), _gauge))))),
            stateRootHash,
            proofs[1].toList()
        ).value;

        userSlope.slope = Verifier.extractSlotValueFromProof(
            keccak256(
                abi.encode(
                    uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(9, _user)), _gauge))))) + 0
                )
            ),
            stateRootHash,
            proofs[4].toList()
        ).value;

        userSlope.power = Verifier.extractSlotValueFromProof(
            keccak256(
                abi.encode(
                    uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(9, _user)), _gauge))))) + 1
                )
            ),
            stateRootHash,
            proofs[5].toList()
        ).value;

        userSlope.end = Verifier.extractSlotValueFromProof(
            keccak256(
                abi.encode(
                    uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(9, _user)), _gauge))))) + 2
                )
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
                        uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(12, _gauge)), time)))))
                            + 0
                    )
                ),
                stateRootHash,
                proofs[2].toList()
            ).value;

            weight.slope = Verifier.extractSlotValueFromProof(
                keccak256(
                    abi.encode(
                        uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(12, _gauge)), time)))))
                            + 1
                    )
                ),
                stateRootHash,
                proofs[3].toList()
            ).value;
        } 
    }

    function setAnycall(address _anycall) external {
        require(msg.sender == owner); // dev: only owner
        ANYCALL = _anycall;
    }

    function setEthBlockHash(uint256 _eth_block_number, bytes32 __eth_blockhash) external {
        // either a cross-chain call from `self` or `owner` is valid to set the blockhash
        if (msg.sender == ANYCALL) {
            (address sender, uint256 from_chain_id) = IAnyCallProxy(msg.sender).context();
            require(sender == address(this) && from_chain_id == 1); // dev: only root self
        } else {
            require(msg.sender == owner); // dev: only owner
        }

        // set the blockhash in storage
        _eth_blockhash[_eth_block_number] = __eth_blockhash;
        emit SetBlockhash(_eth_block_number, __eth_blockhash);

        // update the last block number stored
        if (_eth_block_number > last_eth_block_number) {
            last_eth_block_number = _eth_block_number;
        }
    }
}
