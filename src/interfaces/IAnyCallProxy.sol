// SPDX-License-Identifier: MIT
pragma solidity >=0.8.12;

interface IAnyCallProxy {
    function anyCall(
        address _to,
        bytes calldata _data,
        address _fallback,
        uint256 _toChainID
    ) external;

    function context() external view returns (address, uint256);
}
