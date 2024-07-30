// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "test/utils/Utils.sol";

import {Platform} from "src/Platform.sol";
import {PlatformClaimable} from "src/PlatformClaimable.sol";
import {LibString} from "solady/utils/LibString.sol";
import {AxelarExecutable} from "src/AxelarExecutable.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {GaugeController} from "src/interfaces/GaugeController.sol";
import {EthereumStateSender} from "src/EthereumStateSender.sol";
import {BaseGaugeControllerOracle} from "src/oracles/BaseGaugeControllerOracle.sol";
import {CurveOracle} from "src/oracles/CurveOracle.sol";

contract AxelarGateway {
    function validateContractCall(bytes32, string calldata, string calldata, bytes32) external pure returns (bool) {
        return true;
    }
}

abstract contract BasePlatformTest is Utils {
    using LibString for string;
    using LibString for address;
    using stdStorage for StdStorage;

    EthereumStateSender sender;
    AxelarExecutable axelarExecutable;

    address[] internal oracles;

    // Main Platform Contract
    Platform internal platform;

    PlatformClaimable internal platformClaimable;

    // Bounty Token.
    MockERC20 rewardToken;

    address internal _user;
    address internal _user2;
    address internal _gauge;
    address internal _blacklisted;
    address internal _deployer;

    AxelarGateway internal _gateway;

    // Gauge Controller
    GaugeController internal _gaugeController;

    uint256 internal constant _amount = 10_000e18;

    uint256 internal blockNumber;
    uint256 internal startPeriodBlockNumber;

    string forkRpc = "https://eth.public-rpc.com";

    function setUp() public virtual {
        uint256 forkId = vm.createFork(forkRpc, blockNumber);
        vm.selectFork(forkId);

        _gateway = new AxelarGateway();
        rewardToken = new MockERC20("Token", "TKO", 18);
    }

    function testMultipleOraclesReceivePayload() public virtual {
        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());
        // Get RLP Encoded proofs.
        (bytes32 _block_hash,,) = getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        assertEq(BaseGaugeControllerOracle(oracles[0]).activePeriod(), 0);
        assertEq(BaseGaugeControllerOracle(oracles[1]).activePeriod(), 0);

        // Submit ETH Block Hash to Oracle.
        axelarExecutable.execute(
            "",
            "Ethereum",
            address(sender).toHexStringChecksumed(),
            abi.encodeWithSelector(BaseGaugeControllerOracle.setEthBlockHash.selector, _blockNumber, _block_hash)
        );

        assertEq(BaseGaugeControllerOracle(oracles[0]).activePeriod(), _getCurrentPeriod());
        assertEq(BaseGaugeControllerOracle(oracles[1]).activePeriod(), _getCurrentPeriod());
    }

    function testSetRecipient() public {
        address FAKE_RECIPIENT = address(0xCACA);
        BaseGaugeControllerOracle(oracles[0]).setRecipient(_user, FAKE_RECIPIENT);
        assertEq(BaseGaugeControllerOracle(oracles[0]).recipient(_user), FAKE_RECIPIENT);
    }

    function testSetRecipientWrongAuth() public {
        address FAKE_RECIPIENT = address(0xCACA);

        // Random User
        vm.prank(address(0x1));
        vm.expectRevert(BaseGaugeControllerOracle.NOT_OWNER.selector);
        BaseGaugeControllerOracle(oracles[0]).setRecipient(_user, FAKE_RECIPIENT);
    }

    function testWhitelist() public virtual {
        platform.whitelistAddress(_user, true);
        assertTrue(platform.whitelisted(_user));

        platform.whitelistAddress(_user, false);
        assertFalse(platform.whitelisted(_user));
    }

    function testWhitelistWrongAuth() public virtual {
        // Random User
        vm.prank(address(0x1));
        vm.expectRevert("UNAUTHORIZED");
        platform.whitelistAddress(_user, true);

        assertFalse(platform.whitelisted(_user));
    }

    function testSetBlockHash() public virtual {
        // Create Default Bounty.
        _checkpointGauge(_gauge);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());
        // Get RLP Encoded proofs.
        (bytes32 _block_hash,,) = getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        CurveOracle(oracles[0]).setEthBlockHash(_blockNumber, _block_hash);

        assertEq(CurveOracle(oracles[0]).activePeriod(), _getCurrentPeriod());
    }

    function testSetBlockHashAlreadySet() public virtual {
        // Create Default Bounty.
        _checkpointGauge(_gauge);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());
        // Get RLP Encoded proofs.
        (bytes32 _block_hash,,) = getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        CurveOracle(oracles[0]).setEthBlockHash(_blockNumber, _block_hash);

        assertEq(CurveOracle(oracles[0]).activePeriod(), _getCurrentPeriod());

        vm.expectRevert(BaseGaugeControllerOracle.PERIOD_ALREADY_UPDATED.selector);
        // Submit ETH Block Hash to Oracle.
        CurveOracle(oracles[0]).setEthBlockHash(_blockNumber, _block_hash);
    }

    function testSetBlockHashWithAxelar() public virtual {
        // Create Default Bounty.
        _checkpointGauge(_gauge);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());
        // Get RLP Encoded proofs.
        (bytes32 _block_hash,,) = getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        assertEq(CurveOracle(oracles[0]).activePeriod(), 0);

        // Submit ETH Block Hash to Oracle.
        axelarExecutable.execute(
            "",
            "Ethereum",
            address(sender).toHexStringChecksumed(),
            abi.encodeWithSelector(BaseGaugeControllerOracle.setEthBlockHash.selector, _blockNumber, _block_hash)
        );

        assertEq(CurveOracle(oracles[0]).activePeriod(), _getCurrentPeriod());
    }

    function testClaimable() public virtual {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _checkpointGauge(_gauge);

        skip(1 days);

        (bytes32 block_hash, bytes memory block_header_rlp, bytes memory proof_rlp) = encodeProofs(_gauge, _user);

        // Submit ETH Block Hash to Oracle.
        BaseGaugeControllerOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, block_hash);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        uint256 claimable = platform.claimable(_id, _proofData);
        uint256 claimableOnClaimable = platformClaimable.claimable(platform, _id, _proofData);
        uint256 claimed = platform.claim(_id, _proofData);

        assertGt(claimed, 0);
        assertGt(claimable, 0);
        assertEq(claimable, claimableOnClaimable);
        assertApproxEqRel(claimed, claimable, 1e15);

        assertGt(platform.rewardPerVote(_id), 0);

        claimable = platform.claimable(_id, _proofData);
        claimableOnClaimable = platformClaimable.claimable(platform, _id, _proofData);
        claimed = platform.claim(_id, _proofData);

        assertEq(claimable, 0);
        assertEq(claimed, 0);
        assertEq(claimableOnClaimable, 0);
    }

    function testClaimBribeWithWhitelistedRecipientNotSet() public virtual {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _checkpointGauge(_gauge);

        skip(1 days);

        (bytes32 block_hash, bytes memory block_header_rlp, bytes memory proof_rlp) = encodeProofs(_gauge, _user);

        // Submit ETH Block Hash to Oracle.
        CurveOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, block_hash);
        platform.whitelistAddress(_user, true);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        vm.expectRevert(Platform.NO_RECEIVER_SET_FOR_WHITELISTED.selector);
        platform.claim(_id, _proofData);
    }

    function testClaimBribeWithRecipientSet() public virtual {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _checkpointGauge(_gauge);

        skip(1 days);

        (bytes32 block_hash, bytes memory block_header_rlp, bytes memory proof_rlp) = encodeProofs(_gauge, _user);

        // Submit ETH Block Hash to Oracle.
        CurveOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, block_hash);

        address FAKE_RECIPIENT = address(0xCACA);
        CurveOracle(oracles[0]).setRecipient(_user, FAKE_RECIPIENT);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        uint256 claimed = platform.claim(_id, _proofData);

        assertGt(claimed, 0);

        assertEq(rewardToken.balanceOf(_user), 0);
        assertEq(rewardToken.balanceOf(FAKE_RECIPIENT), claimed);

        assertGt(platform.rewardPerVote(_id), 0);

        claimed = platform.claim(_id, _proofData);
        assertEq(claimed, 0);
    }

    function testClaimBribeWithWhitelistedRecipientSet() public virtual {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _checkpointGauge(_gauge);

        skip(1 days);

        // Build the proof.
        (bytes32 block_hash, bytes memory block_header_rlp, bytes memory proof_rlp) = encodeProofs(_gauge, _user);

        // Submit ETH Block Hash to Oracle.
        CurveOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, block_hash);

        platform.whitelistAddress(_user, true);

        address FAKE_RECIPIENT = address(0xCACA);
        CurveOracle(oracles[0]).setRecipient(_user, FAKE_RECIPIENT);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        uint256 claimable = platform.claimable(_id, _proofData);
        uint256 claimed = platform.claim(_id, _proofData);

        assertGt(claimed, 0);
        assertGt(claimable, 0);
        assertApproxEqRel(claimed, claimable, 1e15);

        assertEq(rewardToken.balanceOf(_user), 0);
        assertEq(rewardToken.balanceOf(FAKE_RECIPIENT), claimed);

        assertGt(platform.rewardPerVote(_id), 0);

        claimed = platform.claim(_id, _proofData);
        claimable = platform.claimable(_id, _proofData);

        assertEq(claimed, 0);
        assertEq(claimable, 0);
    }

    function testClaimBribe() public virtual {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _checkpointGauge(_gauge);

        skip(1 days);

        (bytes32 block_hash, bytes memory block_header_rlp, bytes memory proof_rlp) = encodeProofs(_gauge, _user);

        // Submit ETH Block Hash to Oracle.
        CurveOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, block_hash);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        uint256 claimable = platform.claimable(_id, _proofData);
        uint256 claimed = platform.claim(_id, _proofData);

        assertGt(claimed, 0);
        assertGt(claimable, 0);
        assertApproxEqRel(claimed, claimable, 1e15);

        assertGt(platform.rewardPerVote(_id), 0);

        claimable = platform.claimable(_id, _proofData);
        claimed = platform.claim(_id, _proofData);

        assertEq(claimable, 0);
        assertEq(claimed, 0);
    }

    function testClaimWithBlacklistedAddress() public virtual {
        // Create Default Bounty.
        uint256 _id = _createDefaultBountyWithBlacklist(2 weeks);
        _checkpointGauge(_gauge);

        skip(1 days);

        // Calculate blacklisted bias before sending proof.
        uint256 _bBias = _gaugeController.vote_user_slopes(_blacklisted, _gauge).slope
            * (_gaugeController.vote_user_slopes(_blacklisted, _gauge).end - _getCurrentPeriod());

        (bytes32 block_hash, bytes memory block_header_rlp, bytes memory proof_rlp) = encodeProofs(_gauge, _user);

        (,, bytes memory _blacklisted_proof_rlp) = encodeProofs(_gauge, _blacklisted);

        // Submit ETH Block Hash to Oracle.
        CurveOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, block_hash);

        bytes[] memory _blacklistedProofs = new bytes[](1);
        _blacklistedProofs[0] = _blacklisted_proof_rlp;

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: proof_rlp,
            blackListedProofsRlp: _blacklistedProofs
        });

        assertGt(platform.claim(_id, _proofData), 0);

        // Get RLP Encoded proofs.
        (uint256 _slope,, uint256 _bEnd) =
            CurveOracle(oracles[0]).voteUserSlope(startPeriodBlockNumber, _blacklisted, _gauge);
        assertEq(_bBias, _slope * (_bEnd - _getCurrentPeriod()));
    }

    function testCloseBribe() public virtual {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(3 weeks);
        _checkpointGauge(_gauge);

        (bytes32 block_hash, bytes memory block_header_rlp, bytes memory proof_rlp) = encodeProofs(_gauge, _user);

        // Submit ETH Block Hash to Oracle.
        CurveOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, block_hash);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        uint256 claimed = platform.claim(_id, _proofData);
        assertEq(claimed, 0);

        vm.prank(_user);
        platform.closeBounty(_id);
        assertEq(rewardToken.balanceOf(_user), 0);
    }

    function testClaimMultipleTimes() public virtual {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _checkpointGauge(_gauge);

        skip(1 days);

        (bytes32 block_hash, bytes memory block_header_rlp, bytes memory proof_rlp) = encodeProofs(_gauge, _user);

        // Submit ETH Block Hash to Oracle.
        CurveOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, block_hash);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        uint256 claimable = platform.claimable(_id, _proofData);
        uint256 claimed = platform.claim(_id, _proofData);

        assertGt(claimed, 0);
        assertGt(claimable, 0);
        assertApproxEqRel(claimed, claimable, 1e15);

        claimable = platform.claimable(_id, _proofData);
        claimed = platform.claim(_id, _proofData);

        assertEq(claimable, 0);
        assertEq(claimed, 0);

        // Second user can claim without passing header proof (already stored by first claim)

        (,, bytes memory proof_rlp_bis) = encodeProofs(_gauge, _user2);

        Platform.ProofData memory _proofDataBis = Platform.ProofData({
            user: _user2,
            headerRlp: bytes(""),
            userProofRlp: proof_rlp_bis,
            blackListedProofsRlp: new bytes[](0)
        });

        uint256 claimedBis = platform.claim(_id, _proofDataBis);

        assertGt(claimedBis, 0);

        assertGt(platform.rewardPerVote(_id), 0);
    }

    ////////////////////////////////////////////////////////////
    /// --- Helpers
    ////////////////////////////////////////////////////////////

    function encodeProofs(address gauge, address user)
        public
        virtual
        returns (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp)
    {}

    function _checkpointGauge(address gauge) internal virtual {
        _gaugeController.checkpoint_gauge(gauge);
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
        _id = platform.createBounty(
            gauge, _user, address(_rewardToken), _numberOfPeriods, _maxRewardPerVote, _amount, _blacklist, upgradeable
        );
        _overrideBountyPeriod(_id, numberOfWeeks);
    }

    function _createDefaultBounty(uint256 numberOfWeeks) internal virtual returns (uint256 _id) {
        _id = platform.createBounty(_gauge, _user, address(rewardToken), 2, 2e18, _amount, new address[](0), true);
        //_overrideBountyPeriod(_id, numberOfWeeks);
    }

    function _createDefaultBountyWithBlacklist(uint256 numberOfWeeks) internal returns (uint256 _id) {
        address[] memory _blacklist = new address[](1);
        _blacklist[0] = _blacklisted;

        _id = platform.createBounty(_gauge, _user, address(rewardToken), 2, 2e18, _amount, _blacklist, true);
        //_overrideBountyPeriod(_id, numberOfWeeks);
    }

    function _getCurrentPeriod() internal view returns (uint256) {
        return block.timestamp / 1 weeks * 1 weeks;
    }

    /// Move starting period to current period to avoid issues with calculating proof.
    function _overrideBountyPeriod(uint256 _id, uint256 numberOfWeeks) internal {
        uint256 currentPeriod = _getCurrentPeriod();
        Platform.Bounty memory _bribe = platform.getBounty(_id);

        stdstore.target(address(platform)).sig("bounties(uint256)").with_key(_id).depth(4).checked_write(
            _bribe.endTimestamp - numberOfWeeks
        );
        stdstore.target(address(platform)).sig("activePeriod(uint256)").with_key(_id).depth(1).checked_write(
            currentPeriod
        );

        Platform.Period memory _period = platform.getActivePeriod(_id);
        assertEq(_period.timestamp, _getCurrentPeriod());
    }
}
