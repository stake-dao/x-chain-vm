// SPDX-License-Identifier: MIT
pragma solidity >=0.8.12;

interface ICurveGaugeControllerOracle {
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

    function voteUserSlopes(
        uint256 _block,
        address _user,
        address _gauge
    ) external view returns (VotedSlope memory);

    function lastUserVote(
        uint256 _block,
        address _user,
        address _gauge
    ) external view returns (uint256);

    function userUpdated(
        uint256 _block,
        address _user,
        address _gauge
    ) external view returns (bool);

    function submit_state(
        address _user,
        address _gauge,
        bytes calldata _block_header_rlp,
        bytes calldata _proof_rlp
    ) external;
}
