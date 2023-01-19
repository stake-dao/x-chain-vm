// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "test/utils/Utils.sol";

import {Platform} from "src/Platform.sol";
import {LibString} from "solady/utils/LibString.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {GaugeController} from "src/interfaces/GaugeController.sol";
import {EthereumStateSender} from "src/EthereumStateSender.sol";
import {CurveGaugeControllerOracle} from "src/CurveGaugeControllerOracle.sol";

contract PlatformXChainTest is Utils {
    using LibString for string;
    using LibString for address;
    using stdStorage for StdStorage;

    EthereumStateSender sender;
    CurveGaugeControllerOracle oracle;

    // Main Platform Contract
    Platform internal platform;

    // Bribe Token.
    MockERC20 rewardToken = new MockERC20("Token", "TKO", 18);

    address internal constant _user = 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6;
    address internal constant _gauge = 0x1cEBdB0856dd985fAe9b8fEa2262469360B8a3a6;
    address internal constant _blacklisted = 0x425d16B0e08a28A3Ff9e4404AE99D78C0a076C5A;

    address internal constant _ANYCALL = 0x37414a8662bC1D25be3ee51Fb27C2686e2490A89;

    // Gauge Controller
    GaugeController internal constant _gaugeController = GaugeController(0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB);

    uint256 internal constant _amount = 10_000e18;

    function setUp() public {
        sender = new EthereumStateSender();

        oracle = new CurveGaugeControllerOracle(_ANYCALL);

        platform = new Platform(address(oracle));

        rewardToken.mint(address(this), _amount);
        rewardToken.approve(address(platform), _amount);
    }

    function testLibString() public {
        address _addr = address(0x123);
        string memory _str = "0x0000000000000000000000000000000000000123";

        assertTrue(_str.eq(_addr.toHexStringChecksumed()));
    }

    function testSetRecipient() public {
        address FAKE_RECIPIENT = address(0xCACA);
        oracle.set_recipient(_user, FAKE_RECIPIENT);
        assertEq(oracle.recipient(_user), FAKE_RECIPIENT);
    }

    function testSetRecipientWrongAuth() public {
        address FAKE_RECIPIENT = address(0xCACA);

        // Random User
        vm.prank(address(0x1));
        vm.expectRevert(CurveGaugeControllerOracle.NOT_OWNER.selector);
        oracle.set_recipient(_user, FAKE_RECIPIENT);
    }

    function testWhitelist() public {
        platform.whitelistAddress(_user, true);
        assertTrue(platform.whitelisted(_user));

        platform.whitelistAddress(_user, false);
        assertFalse(platform.whitelisted(_user));
    }

    function testWhitelistWrongAuth() public {
        // Random User
        vm.prank(address(0x1));
        vm.expectRevert(Platform.NOT_GOVERNANCE.selector);
        platform.whitelistAddress(_user, true);

        assertFalse(platform.whitelisted(_user));
    }

    function testSetBlockHash() public {
        // Create Default Bribe.
        _gaugeController.checkpoint_gauge(_gauge);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());
        // Get RLP Encoded proofs.
        (bytes32 _block_hash,,) = getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.set_eth_blockhash(_blockNumber, _block_hash);

        assertEq(oracle.activePeriod(), _getCurrentPeriod());
    }

    function testSetBlockHashAlreadySet() public {
        // Create Default Bribe.
        _gaugeController.checkpoint_gauge(_gauge);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());
        // Get RLP Encoded proofs.
        (bytes32 _block_hash,,) = getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.set_eth_blockhash(_blockNumber, _block_hash);

        assertEq(oracle.activePeriod(), _getCurrentPeriod());

        vm.expectRevert(CurveGaugeControllerOracle.PERIOD_ALREADY_UPDATED.selector);
        // Submit ETH Block Hash to Oracle.
        oracle.set_eth_blockhash(_blockNumber, _block_hash);
    }

    function testClaimBribeWithWhitelistedRecipientNotSet() public {
        // Create Default Bribe.
        uint256 _id = _createDefaultBribe(1 weeks);
        _gaugeController.checkpoint_gauge(_gauge);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.set_eth_blockhash(_blockNumber, _block_hash);

        platform.whitelistAddress(_user, true);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: _block_header_rlp,
            userProofRlp: _proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        vm.expectRevert(Platform.NO_RECEIVER_SET_FOR_WHITELISTED.selector);
        platform.claim(_id, _proofData);
    }

    function testClaimBribeWithRecipientSet() public {
        // Create Default Bribe.
        uint256 _id = _createDefaultBribe(1 weeks);
        _gaugeController.checkpoint_gauge(_gauge);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.set_eth_blockhash(_blockNumber, _block_hash);

        address FAKE_RECIPIENT = address(0xCACA);
        oracle.set_recipient(_user, FAKE_RECIPIENT);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: _block_header_rlp,
            userProofRlp: _proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        uint256 claimed = platform.claim(_id, _proofData);

        assertGt(claimed, 0);

        assertEq(rewardToken.balanceOf(_user), 0);
        assertEq(rewardToken.balanceOf(FAKE_RECIPIENT), claimed);

        assertGt(platform.rewardPerToken(_id), 0);

        claimed = platform.claim(_id, _proofData);
        assertEq(claimed, 0);
    }

    function testClaimBribeWithWhitelistedRecipientSet() public {
        // Create Default Bribe.
        uint256 _id = _createDefaultBribe(1 weeks);
        _gaugeController.checkpoint_gauge(_gauge);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.set_eth_blockhash(_blockNumber, _block_hash);

        platform.whitelistAddress(_user, true);

        address FAKE_RECIPIENT = address(0xCACA);
        oracle.set_recipient(_user, FAKE_RECIPIENT);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: _block_header_rlp,
            userProofRlp: _proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        uint256 claimed = platform.claim(_id, _proofData);

        assertGt(claimed, 0);

        assertEq(rewardToken.balanceOf(_user), 0);
        assertEq(rewardToken.balanceOf(FAKE_RECIPIENT), claimed);

        assertGt(platform.rewardPerToken(_id), 0);

        claimed = platform.claim(_id, _proofData);
        assertEq(claimed, 0);
    }

    function testClaimBribe() public {
        // Create Default Bribe.
        uint256 _id = _createDefaultBribe(1 weeks);
        _gaugeController.checkpoint_gauge(_gauge);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.set_eth_blockhash(_blockNumber, _block_hash);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: _block_header_rlp,
            userProofRlp: _proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        uint256 claimed = platform.claim(_id, _proofData);

        assertGt(claimed, 0);
        assertGt(platform.rewardPerToken(_id), 0);

        claimed = platform.claim(_id, _proofData);
        assertEq(claimed, 0);
    }

    function testClaimWithBlacklistedAddress() public {
        // Create Default Bribe.
        uint256 _id = _createDefaultBribeWithBlacklist(2 weeks);
        _gaugeController.checkpoint_gauge(_gauge);

        // Calculate blacklisted bias before sending proof.
        uint256 _bBias = _gaugeController.vote_user_slopes(_blacklisted, _gauge).slope
            * (_gaugeController.vote_user_slopes(_blacklisted, _gauge).end - _getCurrentPeriod());

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Build the proof.
        (,,, _positions,) = sender.generateEthProofParams(_blacklisted, _gauge, _getCurrentPeriod());

        (,, bytes memory _blacklisted_proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.set_eth_blockhash(_blockNumber, _block_hash);

        bytes[] memory _blacklistedProofs = new bytes[](1);
        _blacklistedProofs[0] = _blacklisted_proof_rlp;

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: _block_header_rlp,
            userProofRlp: _proof_rlp,
            blackListedProofsRlp: _blacklistedProofs
        });

        assertGt(platform.claim(_id, _proofData), 0);

        // Get RLP Encoded proofs.
        (uint256 _slope,, uint256 _bEnd) = oracle.voteUserSlope(_blockNumber, _blacklisted, _gauge);
        assertEq(_bBias, _slope * (_bEnd - _getCurrentPeriod()));
    }

    function testCloseBribe() public {
        // Create Default Bribe.
        uint256 _id = _createDefaultBribe(3 weeks);
        _gaugeController.checkpoint_gauge(_gauge);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.set_eth_blockhash(_blockNumber, _block_hash);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: _block_header_rlp,
            userProofRlp: _proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        uint256 claimed = platform.claim(_id, _proofData);
        assertEq(claimed, 0);

        vm.prank(_user);
        platform.closeBribe(_id);
        assertEq(rewardToken.balanceOf(_user), _amount);
    }

    function _createCustomBribe(
        address gauge,
        address _rewardToken,
        uint8 _numberOfPeriods,
        uint256 _maxRewardPerVote,
        uint256,
        address[] memory _blacklist,
        bool upgradeable,
        uint256 numberOfWeeks
    ) internal returns (uint256 _id) {
        _id = platform.createBribe(
            gauge, _user, address(_rewardToken), _numberOfPeriods, _maxRewardPerVote, _amount, _blacklist, upgradeable
        );
        _overrideBribePeriod(_id, numberOfWeeks);
    }

    function _createDefaultBribe(uint256 numberOfWeeks) internal returns (uint256 _id) {
        _id = platform.createBribe(_gauge, _user, address(rewardToken), 2, 2e18, _amount, new address[](0), true);
        _overrideBribePeriod(_id, numberOfWeeks);
    }

    function _createDefaultBribeWithBlacklist(uint256 numberOfWeeks) internal returns (uint256 _id) {
        address[] memory _blacklist = new address[](1);
        _blacklist[0] = _blacklisted;

        _id = platform.createBribe(_gauge, _user, address(rewardToken), 2, 2e18, _amount, _blacklist, true);
        _overrideBribePeriod(_id, numberOfWeeks);
    }

    function _getCurrentPeriod() internal view returns (uint256) {
        return block.timestamp / 1 weeks * 1 weeks;
    }

    /// Move starting period to current period to avoid issues with calculating proof.
    function _overrideBribePeriod(uint256 _id, uint256 numberOfWeeks) internal {
        uint256 currentPeriod = _getCurrentPeriod();
        Platform.Bribe memory _bribe = platform.getBribe(_id);

        stdstore.target(address(platform)).sig("bribes(uint256)").with_key(_id).depth(4).checked_write(
            _bribe.endTimestamp - numberOfWeeks
        );
        stdstore.target(address(platform)).sig("activePeriod(uint256)").with_key(_id).depth(1).checked_write(
            currentPeriod
        );

        Platform.Period memory _period = platform.getActivePeriod(_id);
        assertEq(_period.timestamp, _getCurrentPeriod());
    }
}
