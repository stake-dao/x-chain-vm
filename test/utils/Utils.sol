// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

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

    function getRLPEncodedProofsBsc(string memory _rpcUrl, uint256 _blockNumber, string memory _account)
        internal
        returns (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp)
    {
        string[] memory inputs = new string[](5);
        inputs[0] = "python3";
        inputs[1] = "test/python/get_proof_bsc.py";
        inputs[2] = _rpcUrl;
        inputs[3] = vm.toString(_blockNumber);
        inputs[4] = _account;
        return abi.decode(vm.ffi(inputs), (bytes32, bytes, bytes));
    }

    function getRLPEncodedProofsForGaugeController(
        string memory rpcUrl,
        address _gaugeController,
        address _user,
        address _gauge,
        uint256 _blockNumber,
        uint256 _timestamp
    ) internal returns (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) {
        // Computed differently depending on the gauge controller
        string[] memory inputs = new string[](8);
        inputs[0] = "python3";
        inputs[1] = "test/python/get_proof_gauge_controller.py";
        inputs[2] = rpcUrl;
        inputs[3] = vm.toString(_gaugeController);
        inputs[4] = vm.toString(_user);
        inputs[5] = vm.toString(_gauge);
        inputs[6] = vm.toString(_blockNumber);
        inputs[7] = vm.toString(_timestamp);
        return abi.decode(vm.ffi(inputs), (bytes32, bytes, bytes));
    }

    function stringToAddress(string memory str) public pure returns (address) {
        bytes memory strBytes = bytes(str);
        require(strBytes.length == 42, "Invalid address length");
        bytes memory addrBytes = new bytes(20);

        for (uint256 i = 0; i < 20; i++) {
            addrBytes[i] = bytes1(hexCharToByte(strBytes[2 + i * 2]) * 16 + hexCharToByte(strBytes[3 + i * 2]));
        }

        return address(uint160(bytes20(addrBytes)));
    }

    function hexCharToByte(bytes1 char) internal pure returns (uint8) {
        uint8 byteValue = uint8(char);
        if (byteValue >= uint8(bytes1("0")) && byteValue <= uint8(bytes1("9"))) {
            return byteValue - uint8(bytes1("0"));
        } else if (byteValue >= uint8(bytes1("a")) && byteValue <= uint8(bytes1("f"))) {
            return 10 + byteValue - uint8(bytes1("a"));
        } else if (byteValue >= uint8(bytes1("A")) && byteValue <= uint8(bytes1("F"))) {
            return 10 + byteValue - uint8(bytes1("A"));
        }
        revert("Invalid hex character");
    }
}
