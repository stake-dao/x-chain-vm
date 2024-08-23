// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.20;

import {IPlatform} from "src/interfaces/IPlatform.sol";

contract MockPancakePlatform is IPlatform {
    function claim(
        uint256 _bountyId,
        address _gauge,
        uint256 _dataTs,
        uint256 _gaugeBias,
        ClaimData[] memory _claimData
    ) external {}
}
