// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IGaugeVoting {
    struct Point {
        uint256 bias;
        uint256 slope;
    }

    struct VotedSlope {
        uint256 slope;
        uint256 power;
        uint256 end;
    }

    function activePeriod() external view returns (uint256);

    function lastUserVote(address _user, bytes32 _gaugeHash) external view returns (uint256);

    function gaugePointsWeight(bytes32 _gaugeHash, uint256 _time) external view returns (Point memory);

    function voteUserSlopes(address _user, bytes32 _gaugeHash) external view returns (VotedSlope memory);
}
