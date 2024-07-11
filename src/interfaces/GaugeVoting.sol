// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface GaugeVoting {
    function checkpointGauge(address _gauge, uint256 _chainId) external;
}
