// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPlatformNoProof {
    struct ClaimData {
        address user;
        uint256 lastVote;
        uint256 gaugeBias;
        uint256 gaugeSlope;
        uint256 userVoteSlope;
        uint256 userVotePower;
        uint256 userVoteEnd;
    }
}
