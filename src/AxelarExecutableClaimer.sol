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

    /// @notice Ethereum State Sender
    address public ess;
    address public platform;
    string public strEss;
    string public srcChain;

    event PlatformSet(address platform);
    event EssSet(address ess);

    constructor(address _axelarGateway, address _sourceAddress, string memory _srcChain, address _platform)
        IAxelarExecutable(_axelarGateway)
        Owned(msg.sender)
    {
        ess = _sourceAddress;
        srcChain = _srcChain;
        strEss = _sourceAddress.toHexStringChecksumed();
        platform = _platform;
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

        (bool success,) = platform.call(payload);
        if (!success) revert CALL_FAILED();
    }

    /// @notice Set new vm platform
    /// @param _platform platform address
    function setPlatform(address _platform) external onlyOwner {
        platform = _platform;
        emit PlatformSet(platform);
    }

    /// @notice Set a new ethereum state sender
    /// @param _ess ess address
    function setEthStateSender(address _ess) external onlyOwner {
        ess = _ess;
        strEss = _ess.toHexStringChecksumed();
        emit EssSet(ess);
    }
}
