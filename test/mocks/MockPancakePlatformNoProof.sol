// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.20;

import {IPlatformNoProof} from "src/interfaces/IPlatformNoProof.sol";

contract MockPancakePlatformNoProof is IPlatformNoProof {
    function claim(
        uint256 _bountyId,
        address _recipient,
        address _gauge,
        uint256 _dataTs,
        uint256 _gaugeBias,
        ClaimData memory _claimData,
        ClaimData[] memory _blacklistData
    ) external {}

    function claimWithProxy(
        uint256 _bountyId,
        address _recipient,
        address _gauge,
        uint256 _dataTs,
        uint256 _gaugeBias,
        ClaimData memory _userClaimData,
        ClaimData memory _proxyClaimData,
        ClaimData[] memory _blacklistClaimData
    ) external {}
}
