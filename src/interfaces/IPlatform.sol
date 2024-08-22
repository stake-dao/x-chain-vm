// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPlatform {
    struct ClaimData {
        address user;
        uint256 lastVote;
        uint256 userVoteBias;
    }

    function claim(
        uint256 _bountyId,
        address _gauge,
        uint256 _dataTs,
        uint256 _gaugeBias,
        ClaimData[] memory _claimData
    ) external;
}
