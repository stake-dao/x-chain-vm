// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Owned} from "solmate/auth/Owned.sol";
import {LibString} from "solady/utils/LibString.sol";
import {IAxelarExecutable, IAxelarGateway} from "src/interfaces/IAxelarExecutable.sol";

contract AxelarExecutable is IAxelarExecutable, Owned {
    using LibString for string;
    using LibString for address;

    error NOT_OWNER();
    error CALL_FAILED();
    error WRONG_SOURCE_CHAIN();
    error WRONG_SOURCE_ADDRESS();

    /// @notice Curve Gauge Controller Oracle.
    address public immutable ORACLE;

    /// @notice Ethereum State Sender
    address public immutable ETH_STATE_SENDER;

    // Not supported yet for immutable string.
    string public STR_ETH_STATE_SENDER;

    constructor(address _axelarGateway, address _sourceAddress, address _oracle)
        IAxelarExecutable(_axelarGateway)
        Owned(msg.sender)
    {
        ORACLE = _oracle;
        ETH_STATE_SENDER = _sourceAddress;
        STR_ETH_STATE_SENDER = _sourceAddress.toHexStringChecksumed();
    }

    function _execute(string memory sourceChain, string memory sourceAddress, bytes calldata payload)
        internal
        override
    {
        if (!sourceChain.eq("Ethereum")) revert WRONG_SOURCE_CHAIN();
        if (!sourceAddress.eq(STR_ETH_STATE_SENDER)) revert WRONG_SOURCE_ADDRESS();

        (bool success,) = ORACLE.call(payload);
        if (!success) revert CALL_FAILED();
    }
}
