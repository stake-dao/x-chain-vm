// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IGaugeControllerOracle {
    struct Point {
        uint256 bias;
        uint256 slope;
    }

    struct VotedSlope {
        uint256 slope;
        uint256 power;
        uint256 end;
    }

    function pointWeights(address _gauge, uint256 _time) external view returns (Point memory);

    function activePeriod() external view returns (uint256);

    function recipient(address _sender) external view returns (address);

    function last_eth_block_number() external view returns (uint256);

    function voteUserSlope(uint256 _block, address _user, address _gauge) external view returns (VotedSlope memory);

    function lastUserVote(uint256 _block, address _user, address _gauge) external view returns (uint256);

    function isUserUpdated(uint256 _block, address _user, address _gauge) external view returns (bool);

    function submit_state(address _user, address _gauge, bytes calldata _block_header_rlp, bytes calldata _proof_rlp)
        external;

    function extractProofState(address _user, address _gauge, bytes memory _block_header_rlp, bytes memory _proof_rlp)
        external
        view
        returns (Point memory, VotedSlope memory, uint256, uint256);
}
