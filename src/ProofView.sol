// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

contract ProofView {




    function _getBalancerPositions(address _user, address _gauge, uint256 _time)
        internal
        view
        returns (address, address, uint256, uint256[6] memory _positions, uint256)
    {
        uint256 lastUserVotePosition = uint256(keccak256(abi.encode(keccak256(abi.encode(1000000007, _user)), _gauge)));
        _positions[0] = lastUserVotePosition;
        uint256 pointWeightsPosition = uint256(keccak256(abi.encode(keccak256(abi.encode(1000000008, _gauge)), _time)));
        uint256 i;
        for (i = 0; i < 2; i++) {
            _positions[1 + i] = pointWeightsPosition + i;
        }

        uint256 voteUserSlopePosition = uint256(keccak256(abi.encode(keccak256(abi.encode(1000000005, _user)), _gauge)));
        for (i = 0; i < 3; i++) {
            _positions[3 + i] = voteUserSlopePosition + i;
        }
        return (_user, _gauge, _time, _positions, block.number);
    }
}
