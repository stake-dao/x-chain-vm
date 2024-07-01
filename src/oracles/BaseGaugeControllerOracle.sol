// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

import {Owned} from "solmate/auth/Owned.sol";
import {LibString} from "solady/utils/LibString.sol";
import {RLPReader} from "src/merkle-utils/RLPReader.sol";
import {StateProofVerifier as Verifier} from "src/merkle-utils/StateProofVerifier.sol";

abstract contract BaseGaugeControllerOracle is Owned {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;
    using LibString for address;
    using LibString for string;

    struct Point {
        uint256 bias;
        uint256 slope;
    }

    struct VotedSlope {
        uint256 slope;
        uint256 power;
        uint256 end;
    }

    address public immutable GAUGE_CONTROLLER;
    bytes32 public immutable GAUGE_CONTROLLER_HASH;

    // Genesis ETH blockhash.
    bytes32 constant GENESIS_BLOCKHASH = 0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3;

    error NOT_OWNER();
    error INVALID_HASH();
    error WRONG_CONTEXT();
    error WRONG_DECODING();
    error WRONG_SOURCE_CHAIN();
    error WRONG_SOURCE_ADDRESS();
    error INVALID_BLOCK_HEADER();
    error INVALID_PROOF_LENGTH();
    error INVALID_HASH_MISMATCH();
    error PERIOD_ALREADY_UPDATED();
    error GAUGE_CONTROLLER_NOT_FOUND();

    address public axelarExecutable;

    /// Mapping of Ethereum block number to blockhash
    mapping(uint256 => bytes32) internal _eth_blockhash;

    /// Mapping of Ethereum block number to blockhash
    mapping(uint256 => bytes32) internal _state_root_hash;

    // Mapping of Ethereum block number to block header RLP
    mapping(uint256 => bytes) internal block_header_rlp;

    /// Last Ethereum block number which had its blockhash stored
    uint256 public last_eth_block_number;

    uint256 public activePeriod;

    /// Mapping of desired recipient for an address.
    mapping(address => address) public recipient;

    /// @notice Mapping of Gauge => Block Number => Point Weight Struct.
    mapping(address => mapping(uint256 => Point)) public pointWeights;

    /// @notice Mapping of Block Number => Address => Gauge => isUpdated for the specific block number.
    mapping(uint256 => mapping(address => mapping(address => bool))) public isUserUpdated;

    /// @notice Mapping of Block Number => Address => Gauge => lastUserVote timestamp.
    mapping(uint256 => mapping(address => mapping(address => uint256))) public lastUserVote;

    /// @notice Mapping of Block Number => Address => Gauge => VotedSlope values.
    mapping(uint256 => mapping(address => mapping(address => VotedSlope))) public voteUserSlope;

    /// Log a blockhash update
    event SetBlockhash(uint256 _eth_block_number, bytes32 _eth_blockhash);

    event SetRecipient(address indexed _user, address indexed _recipient);

    constructor(address _axelarExecutable, address _gaugeController) Owned(msg.sender) {
        axelarExecutable = _axelarExecutable;
        GAUGE_CONTROLLER = _gaugeController;
        GAUGE_CONTROLLER_HASH = keccak256(abi.encodePacked(GAUGE_CONTROLLER));

        emit SetBlockhash(0, _eth_blockhash[0] = GENESIS_BLOCKHASH);
    }

    function submit_state(address _user, address _gauge, bytes memory block_header_rlp_, bytes memory _proof_rlp)
        external
    {
        // If not set for the last block number, set it
        if (block_header_rlp[last_eth_block_number].length == 0) {
            if (block_header_rlp_.length == 0) revert INVALID_BLOCK_HEADER();
            block_header_rlp[last_eth_block_number] = block_header_rlp_;
        }

        bytes memory _block_header_rlp = block_header_rlp[last_eth_block_number];

        // Verify the state proof
        (
            Point memory point,
            VotedSlope memory votedSlope,
            uint256 lastVote,
            uint256 blockNumber,
            bytes32 stateRootHash
        ) = _extractProofState(_user, _gauge, _block_header_rlp, _proof_rlp);

        if (
            point.bias == 0 || point.slope == 0 || votedSlope.slope == 0 || votedSlope.power == 0
                || votedSlope.end == 0 || lastVote == 0 || blockNumber == 0
        ) revert WRONG_DECODING();

        pointWeights[_gauge][blockNumber] = point;
        voteUserSlope[blockNumber][_user][_gauge] = votedSlope;
        lastUserVote[blockNumber][_user][_gauge] = lastVote;
        isUserUpdated[blockNumber][_user][_gauge] = true;

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
        // Use cached block header RLP if available
        if (block_header_rlp[last_eth_block_number].length > 0) {
            _block_header_rlp = block_header_rlp[last_eth_block_number];
        }

        return _extractProofState(_user, _gauge, _block_header_rlp, _proof_rlp);
    }

    function _extractProofState(address _user, address _gauge, bytes memory _block_header_rlp, bytes memory _proof_rlp)
        internal
        view
        virtual
        returns (
            Point memory weight,
            VotedSlope memory userSlope,
            uint256 lastVote,
            uint256 blockNumber,
            bytes32 stateRootHash
        )
    {}

    function setAxelarExecutable(address _axelarExecutable) external {
        if (msg.sender != owner) revert NOT_OWNER();
        axelarExecutable = _axelarExecutable;
    }

    function setRecipient(address _sender, address _recipient) external {
        // either a cross-chain call from `self` or `owner` is valid to set the blockhash
        if (msg.sender != owner && msg.sender != address(axelarExecutable)) revert NOT_OWNER();

        recipient[_sender] = _recipient;
        emit SetRecipient(_sender, _recipient);
    }

    function setEthBlockHash(uint256 _eth_block_number, bytes32 __eth_blockhash) public {
        // either a cross-chain call from `self` or `owner` is valid to set the blockhash
        if (msg.sender != owner && msg.sender != address(axelarExecutable)) revert NOT_OWNER();

        uint256 _period = block.timestamp / 1 weeks * 1 weeks;
        if (activePeriod >= _period) revert PERIOD_ALREADY_UPDATED();

        // set the blockhash in storage
        _eth_blockhash[_eth_block_number] = __eth_blockhash;
        activePeriod = _period;
        emit SetBlockhash(_eth_block_number, __eth_blockhash);

        // update the last block number stored
        if (_eth_block_number > last_eth_block_number) {
            last_eth_block_number = _eth_block_number;
        }
    }

    function setEthBlockHashEmergency(uint256 _eth_block_number, bytes32 __eth_blockhash) external {
        if (msg.sender != owner) revert NOT_OWNER();

        uint256 _period = block.timestamp / 1 weeks * 1 weeks;

        _eth_blockhash[_eth_block_number] = __eth_blockhash;
        activePeriod = _period;
        emit SetBlockhash(_eth_block_number, __eth_blockhash);

        last_eth_block_number = _eth_block_number;
    }
}
