// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "test/utils/Utils.sol";
import "forge-std/Script.sol";

import {Platform} from "src/Platform.sol";
import {AxelarExecutable} from "src/AxelarExecutable.sol";
import {EthereumStateSender} from "src/EthereumStateSender.sol";
import {CurveGaugeControllerOracle} from "src/CurveGaugeControllerOracle.sol";
import {StateProofVerifier as Verifier} from "src/merkle-utils/StateProofVerifier.sol";

contract DeploySideChains is Script, Utils {
    /// Ethereum State Sender.
    address internal constant ETH_STATE_SENDER = 0xC19d317c84e43F93fFeBa146f4f116A6F2B04663;

    /// Arbitrum Axelar Gateway.
    address internal constant _AXELAR_GATEWAY = 0xe432150cce91c13a887f7D836923d5597adD8E31;

    address internal constant _gaugeController = 0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB;

    address _user = 0x6Ae7bf291028CCf52991BD020D2Dc121b40bce2A;

    Platform platform;
    CurveGaugeControllerOracle oracle;
    AxelarExecutable axelarExecutable;

    address internal constant DEPLOYER = 0x0dE5199779b43E13B3Bec21e91117E18736BC1A8;

    function run() public {
        vm.startPrank(_user);
        uint256 forkId = vm.createFork("https://eth.public-rpc.com"); // February 1st
        vm.selectFork(forkId);

        // oracle = new CurveGaugeControllerOracle(address(0));
        // axelarExecutable = new AxelarExecutable(_AXELAR_GATEWAY, ETH_STATE_SENDER, address(oracle));
        // oracle.setAxelarExecutable(address(axelarExecutable));

        // platform = new Platform(address(oracle), DEPLOYER, DEPLOYER);

        address _gauge = 0x663FC22e92f26C377Ddf3C859b560C4732ee639a;
        address _platform = 0xd69414111e51468cFB431e620CBccFbebf9C7dA0;

        address _blacklist = 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6;

        uint256 bountyId = 0;

        (,,, uint256[6] memory _positions, uint256 _blockNumber) = EthereumStateSender(payable(ETH_STATE_SENDER))
            .generateEthProofParams(_user, _gauge, block.timestamp / 1 weeks * 1 weeks);

        (,,, uint256[6] memory _positions_2,) = EthereumStateSender(payable(ETH_STATE_SENDER)).generateEthProofParams(
            _blacklist, _gauge, block.timestamp / 1 weeks * 1 weeks
        );

        // Get RLP Encoded proofs.

        forkId = vm.createFork("https://arbitrum.blockpi.network/v1/rpc/public"); // February 1st
        vm.selectFork(forkId);

        _blockNumber = 17086287;

        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", _gaugeController, _positions, _blockNumber);

        // Get RLP Encoded proofs.
        (,, bytes memory _blacklist_proof_rlp) =
            getRLPEncodedProofs("mainnet", _gaugeController, _positions_2, _blockNumber);

        bytes[] memory _blacklistedProofs = new bytes[](1);
        _blacklistedProofs[0] = _blacklist_proof_rlp;

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: _block_header_rlp,
            userProofRlp: _proof_rlp,
            blackListedProofsRlp: _blacklistedProofs
        });

        oracle = CurveGaugeControllerOracle(address(Platform(_platform).gaugeController()));
        // oracle.extractProofState(_user, _gauge, _block_header_rlp, _proof_rlp);
        // oracle.extractProofState(_blacklist, _gauge, _block_header_rlp, _blacklist_proof_rlp);

        console.log("Claimable", Platform(_platform).claimable(bountyId, _proofData));

        Platform(_platform).claim(bountyId, _proofData);

        vm.stopPrank();
    }
}
