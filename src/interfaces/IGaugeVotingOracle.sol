// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IGaugeVotingOracle {
    struct Point {
        uint256 bias;
        uint256 slope;
    }

    struct VotedSlope {
        uint256 slope;
        uint256 power;
        uint256 end;
    }

    function activePeriod() external view returns (uint256);

    function extractProofState(
        address _user,
        address _gauge,
        uint256 _chainId,
        bytes memory _block_header_rlp,
        bytes memory _proof_rlp
    ) external view returns (Point memory, VotedSlope memory, uint256, uint256);

    function extractVeCakeProofState(address _user, bytes memory _block_hheader_rlp, bytes memory _proof_rlp)
        external
        view
        returns (address, uint256, bytes32);

    function isUserUpdated(uint256 _block, address _user, address _gauge) external view returns (bool);

    function last_eth_block_number() external view returns (uint256);

    function lastUserVote(uint256 _block, address _user, address _gauge) external view returns (uint256);

    function pointWeights(address _gauge, uint256 _time) external view returns (Point memory);

    function recipient(address _sender) external view returns (address);

    function submit_state(
        address _user,
        address _gauge,
        uint256 _chainId,
        bytes calldata _block_header_rlp,
        bytes calldata _proof_rlp
    ) external;

    function veCakeProxies(address _user) external view returns (address);

    function voteUserSlope(uint256 _block, address _user, address _gauge) external view returns (VotedSlope memory);
}
