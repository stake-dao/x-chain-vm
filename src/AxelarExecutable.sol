// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Owned} from "solmate/auth/Owned.sol";
import {LibString} from "solady/utils/LibString.sol";
import {IAxelarExecutable, IAxelarGateway} from "src/interfaces/IAxelarExecutable.sol";

contract AxelarExecutable is IAxelarExecutable, Owned {
    using LibString for string;
    using LibString for address;

    error CALL_FAILED();
    error WRONG_SOURCE_CHAIN();
    error WRONG_SOURCE_ADDRESS();

    /// @notice Curve Gauge Controller Oracle.
    address public oracle;

    /// @notice Ethereum State Sender
    address public ess;
    string public strEss;

    event OracleSet(address oracle);
    event EssSet(address ess);

    constructor(address _axelarGateway, address _sourceAddress, address _oracle)
        IAxelarExecutable(_axelarGateway)
        Owned(msg.sender)
    {
        oracle = _oracle;
        ess = _sourceAddress;
        strEss = _sourceAddress.toHexStringChecksumed();
    }

    function _execute(string memory sourceChain, string memory sourceAddress, bytes calldata payload)
        internal
        override
    {
        if (!sourceChain.eq("Ethereum")) revert WRONG_SOURCE_CHAIN();
        if (!sourceAddress.eq(strEss)) revert WRONG_SOURCE_ADDRESS();

        (bool success,) = oracle.call(payload);
        if (!success) revert CALL_FAILED();
    }

    /// @notice Set a new oracle
    /// @param _oracle oracle address
    function setOracle(address _oracle) external onlyOwner {
        oracle = _oracle;
        emit OracleSet(oracle);
    }

    /// @notice Set a new ethereum state sender
    /// @param _ess ess address
    function setEthStateSender(address _ess) external onlyOwner {
        ess = _ess;
        strEss = _ess.toHexStringChecksumed();
        emit EssSet(ess);
    }
}
