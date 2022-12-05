// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";

abstract contract Utils is Test {
    function getRLPEncodedProofs(
        string memory rpcUrl,
        address _account,
        uint256[6] memory _positions,
        uint256 _blockNumber
    ) internal returns (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) {
        string[] memory inputs = new string[](11);
        inputs[0] = "python3";
        inputs[1] = "test/python/get_proof.py";
        inputs[2] = rpcUrl;
        inputs[3] = vm.toString(_account);
        for (uint256 i = 4; i < 10; i++) {
            inputs[i] = vm.toString(_positions[i - 4]);
        }
        inputs[10] = vm.toString(_blockNumber);
        return abi.decode(vm.ffi(inputs), (bytes32, bytes, bytes));
    }
}
