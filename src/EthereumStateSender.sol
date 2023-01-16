// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LibString} from "solady/utils/LibString.sol";
import {IAxelarGateway} from "src/interfaces/IAxelarGateway.sol";

contract EthereumStateSender {
    using LibString for address;

    address public constant AXELAR_GATEWAY = 0x4F4495243837681061C4743b74B3eEdf548D56A5;

    event RecipientSet(address indexed _sender, address indexed _recipient, string _destinationChain);
    event BlockhashSent(uint256 indexed _blockNumber, bytes32 _blockHash, string _destinationChain);

    function sendBlockhash(string calldata destinationChain, address destinationContract, uint256 _blockNumber)
        external
    {
        bytes32 blockHash = blockhash(_blockNumber);

        string memory _destinationContract = destinationContract.toHexStringChecksumed();

        IAxelarGateway(AXELAR_GATEWAY).callContract(
            destinationChain,
            _destinationContract,
            abi.encode("setEthBlockHash(uint256,bytes32)", _blockNumber, blockHash)
        );

        emit BlockhashSent(_blockNumber, blockHash, destinationChain);
    }

    function setRecipient(string calldata destinationChain, address destinationContract, address _recipient) external {
        string memory _destinationContract = destinationContract.toHexStringChecksumed();

        IAxelarGateway(AXELAR_GATEWAY).callContract(
            destinationChain, _destinationContract, abi.encode("setRecipient(address,address)", msg.sender, _recipient)
        );

        emit RecipientSet(msg.sender, _recipient, destinationChain);
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
