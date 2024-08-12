// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPlatformNoProof {
    struct ClaimData {
        address user;
        uint256 lastVote;
        uint256 userVoteSlope;
        uint256 userVotePower;
        uint256 userVoteEnd;
    }

    function claim(
        uint256 _bountyId,
        address _recipient,
        address _gauge,
        uint256 _dataTs,
        uint256 _gaugeBias,
        ClaimData[] memory _claimData,
        bool _bothClaim
    ) external;
}
