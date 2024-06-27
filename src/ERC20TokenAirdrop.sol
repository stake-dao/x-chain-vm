// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "forge-std/interfaces/IERC20.sol";

/// @title ERC20TokenAirdrop
/// @notice Airdrops ERC20 tokens to a list of addresses
contract ERC20TokenAirdrop {
    event TokensAirdropped(address indexed recipient, uint256 amount);

    error InsufficientBalance();

    constructor() {
    }

    /// @notice Airdrops tokens to a list of recipients
    /// @param recipients List of recipient addresses
    /// @param amounts Corresponding list of amounts to airdrop
    function airdrop(IERC20 token, address[] calldata recipients, uint256[] calldata amounts) external {
        require(recipients.length == amounts.length, "Mismatch between recipients and amounts");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        if (token.balanceOf(address(this)) < totalAmount) revert InsufficientBalance();

        for (uint256 i = 0; i < recipients.length; i++) {
            token.transfer(recipients[i], amounts[i]);
            emit TokensAirdropped(recipients[i], amounts[i]);
        }
    }
}