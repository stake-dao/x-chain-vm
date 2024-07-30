// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {StateSender} from "src/StateSender.sol";

/// @title BnbStateSender
/// @notice Sends weekly period block + block hash to a set of destination chains through Axelar
/// @dev This contract uses Axelar network for cross-chain communication
contract BnbStateSender is StateSender {
    constructor(address _governance, uint256 _sendBlockHashMinValue, uint256 _setRecipientMinValue)
        StateSender(
            _governance,
            0x304acf330bbE08d1e512eefaa92F6a57871fD895,
            0x2d5d7d31F671F86C782533cc367F14109a082712,
            _sendBlockHashMinValue,
            _setRecipientMinValue
        )
    {}
}
