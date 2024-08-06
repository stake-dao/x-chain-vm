// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Owned} from "solmate/auth/Owned.sol";
import {LibString} from "solady/utils/LibString.sol";
import {IAxelarExecutable, IAxelarGateway} from "src/interfaces/IAxelarExecutable.sol";

contract AxelarExecutableClaimer is IAxelarExecutable, Owned {
    using LibString for string;
    using LibString for address;

    error CALL_FAILED();
    error WRONG_SOURCE_CHAIN();
    error WRONG_SOURCE_ADDRESS();

    /// @notice Gauge Controller Oracles.
    address[] public oracles;

    /// @notice Ethereum State Sender
    address public ess;
    string public strEss;
    string public srcChain;

    event OracleSet(address[] oracles);
    event EssSet(address ess);

    constructor(address _axelarGateway, address _sourceAddress, address[] memory _oracles, string memory _srcChain)
        IAxelarExecutable(_axelarGateway)
        Owned(msg.sender)
    {
        oracles = _oracles;
        ess = _sourceAddress;
        srcChain = _srcChain;
        strEss = _sourceAddress.toHexStringChecksumed();
    }

    /// @notice Execute the payload
    /// @param sourceChain source chain
    /// @param sourceAddress source address
    /// @param payload payload
    /// @dev Executing same payload on all oracles
    function _execute(string memory sourceChain, string memory sourceAddress, bytes calldata payload)
        internal
        override
    {
        if (!sourceChain.eq(srcChain)) revert WRONG_SOURCE_CHAIN();
        if (!sourceAddress.eq(strEss)) revert WRONG_SOURCE_ADDRESS();

        for (uint256 i = 0; i < oracles.length; i++) {
            (bool success,) = oracles[i].call(payload);
            if (!success) revert CALL_FAILED();
        }
    }

    /// @notice Set new oracles
    /// @param _oracles oracle addresses
    function setOracles(address[] calldata _oracles) external onlyOwner {
        oracles = _oracles;
        emit OracleSet(oracles);
    }

    /// @notice Set a new ethereum state sender
    /// @param _ess ess address
    function setEthStateSender(address _ess) external onlyOwner {
        ess = _ess;
        strEss = _ess.toHexStringChecksumed();
        emit EssSet(ess);
    }
}
