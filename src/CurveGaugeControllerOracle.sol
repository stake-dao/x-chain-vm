// SPDX-License-Identifier: MIT
pragma solidity >=0.8.12;

import { RLPReader } from "./RLPReader.sol";
import { StateProofVerifier as Verifier } from "./StateProofVerifier.sol";
import { IAnyCallProxy } from "./interfaces/IAnyCallProxy.sol";

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
    /// Address of the AnyCallProxy for the chain this contract is deployed on
    address public immutable ANYCALL;

    /// Mapping of Ethereum block number to blockhash
    mapping(uint256 => bytes32) private _eth_blockhash;

    /// Last Ethereum block number which had its blockhash stored
    uint256 public last_eth_block_number;

    /// Owner of the contract with special privileges
    address public owner;

    mapping(address => mapping(uint256 => Point)) public pointWeights; // gauge => time => Point
    mapping(uint256 => mapping(address => mapping(address => VotedSlope))) public voteUserSlopes; // block -> user -> gauge -> VotedSlope
    mapping(uint256 => mapping(address => mapping(address => uint256))) public lastUserVote; // block -> user -> gauge -> lastUserVote
    mapping(uint256 => mapping(address => mapping(address => bool))) public userUpdated; // block -> user -> gauge -> bool
    /// Log a blockhash update
    event SetBlockhash(uint256 _eth_block_number, bytes32 _eth_blockhash);

    constructor() {
        _eth_blockhash[0] = GENESIS_BLOCKHASH;
        emit SetBlockhash(0, GENESIS_BLOCKHASH);
        owner = msg.sender;

        // ANYCALL = _anycall;
        ANYCALL = 0x0000000000000000000000000000000000000000;
    }

    function submit_state(
        address _user,
        address _gauge,
        uint256 _time,
        bytes memory _block_header_rlp,
        bytes memory _proof_rlp
    ) external {
        Verifier.BlockHeader memory block_header = Verifier.parseBlockHeader(_block_header_rlp);
        require(block_header.hash != bytes32(0), "Wrong hash"); // dev: invalid blockhash
        require(block_header.hash == _eth_blockhash[block_header.number], "hash doesn't match"); // dev: blockhash mismatch
        // convert _proof_rlp into a list of `RLPItem`s
        RLPReader.RLPItem[] memory proofs = _proof_rlp.toRlpItem().toList();
        require(proofs.length == 7);
        // 0th proof is the account proof for Gauge Controller contract
        Verifier.Account memory gauge_controller_account = Verifier.extractAccountFromProof(
            GAUGE_CONTROLLER_HASH, // position of the account is the hash of its address
            block_header.stateRootHash,
            proofs[0].toList()
        );
        require(gauge_controller_account.exists); // dev: Gauge Controller account does not exist
        Verifier.SlotValue memory last_user_vote = Verifier.extractSlotValueFromProof(
            keccak256(abi.encode(uint256(keccak256(abi.encode(keccak256(abi.encode(11, _user)), _gauge))))),
            gauge_controller_account.storageRoot,
            proofs[1].toList()
        );

        uint256 i;
        Verifier.SlotValue[2] memory point_weights;
        for (i = 0; i < 2; i++) {
            point_weights[i] = Verifier.extractSlotValueFromProof(
                keccak256(
                    abi.encode(
                        uint256(
                            keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(12, _gauge)), _time))))
                        ) + i
                    )
                ),
                gauge_controller_account.storageRoot,
                proofs[2 + i].toList()
            );
        }

        Verifier.SlotValue[3] memory vote_user_slopes;
        for (i = 0; i < 3; i++) {
            vote_user_slopes[i] = Verifier.extractSlotValueFromProof(
                keccak256(
                    abi.encode(
                        uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(9, _user)), _gauge))))) +
                            i
                    )
                ),
                gauge_controller_account.storageRoot,
                proofs[4 + i].toList()
            );
        }

        pointWeights[_gauge][_time] = Point(point_weights[0].value, point_weights[1].value);
        voteUserSlopes[block_header.number][_user][_gauge] = VotedSlope(
            vote_user_slopes[0].value,
            vote_user_slopes[1].value,
            vote_user_slopes[2].value
        );
        lastUserVote[block_header.number][_user][_gauge] = last_user_vote.value;
        userUpdated[block_header.number][_user][_gauge] = true;
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
