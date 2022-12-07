// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "src/interfaces/IAnyCallProxy.sol";

contract EthereumStateSender {
    address public constant ANYCALL_PROXY = 0x37414a8662bC1D25be3ee51Fb27C2686e2490A89;
    mapping(uint256 => uint256) public lastSent;

    function sendBlockhash(uint256 _blockNumber, uint256 _chainId) external {
        bytes32 blockHash = blockhash(_blockNumber);

        lastSent[_chainId] = _blockNumber;

        IAnyCallProxy(ANYCALL_PROXY).anyCall(
            address(this), abi.encode(_blockNumber, blockHash, 0x0fb997cc), address(0), _chainId
        );
    }

    function generateEthProofParams(address _user, address _gauge, uint256 _time)
        external
        view
        returns (address, address, uint256, uint256[6] memory _positions, uint256)
    {
        uint256 lastUserVotePosition = uint256(keccak256(abi.encode(keccak256(abi.encode(11, _user)), _gauge)));
        _positions[0] = lastUserVotePosition;
        uint256 pointWeightsPosition =
            uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(12, _gauge)), _time)))));
        uint256 i;
        for (i = 0; i < 2; i++) {
            _positions[1 + i] = pointWeightsPosition + i;
        }

        uint256 voteUserSlopePosition =
            uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(9, _user)), _gauge)))));
        for (i = 0; i < 3; i++) {
            _positions[3 + i] = voteUserSlopePosition + i;
        }
        return (_user, _gauge, _time, _positions, block.number);
    }
}
