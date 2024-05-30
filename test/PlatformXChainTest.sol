// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "test/utils/Utils.sol";

import {Platform} from "src/Platform.sol";
import {PlatformClaimable} from "src/PlatformClaimable.sol";
import {LibString} from "solady/utils/LibString.sol";
import {AxelarExecutable} from "src/AxelarExecutable.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {GaugeController} from "src/interfaces/GaugeController.sol";
import {EthereumStateSender} from "src/EthereumStateSender.sol";
import {CurveGaugeControllerOracle} from "src/CurveGaugeControllerOracle.sol";

contract AxelarGateway {
    function validateContractCall(bytes32, string calldata, string calldata, bytes32) external pure returns (bool) {
        return true;
    }
}

contract PlatformXChainTest is Utils {
    using LibString for string;
    using LibString for address;
    using stdStorage for StdStorage;

    EthereumStateSender sender;
    CurveGaugeControllerOracle oracle;
    AxelarExecutable axelarExecutable;

    // Main Platform Contract
    Platform internal platform;

    PlatformClaimable internal platformClaimable;

    // Bounty Token.
    MockERC20 rewardToken;

    address internal constant _user = 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6;
    address internal constant _gauge = 0x26F7786de3E6D9Bd37Fcf47BE6F2bC455a21b74A;
    address internal constant _blacklisted = 0xecdED8b1c603cF21299835f1DFBE37f10F2a29Af;
    address internal constant _deployer = 0x0dE5199779b43E13B3Bec21e91117E18736BC1A8;

    AxelarGateway internal _gateway;

    // Gauge Controller
    GaugeController internal constant _gaugeController = GaugeController(0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB);

    uint256 internal constant _amount = 10_000e18;

    function setUp() public {
        uint256 forkId = vm.createFork("https://eth.public-rpc.com", 19728000); // Wednesday 24
        vm.selectFork(forkId);

        _gateway = new AxelarGateway();
        rewardToken = new MockERC20("Token", "TKO", 18);

        sender = new EthereumStateSender(_deployer);

        oracle = new CurveGaugeControllerOracle(address(axelarExecutable));
        axelarExecutable = new AxelarExecutable(address(_gateway), address(sender), address(oracle));
        oracle.setAxelarExecutable(address(axelarExecutable));

        platform = new Platform(address(oracle), address(this), address(this));

        // Claimable (view) platform
        platformClaimable = new PlatformClaimable(platform, address(oracle));

        rewardToken.mint(address(this), _amount);
        rewardToken.approve(address(platform), _amount);
    }

    function testSetRecipient() public {
        address FAKE_RECIPIENT = address(0xCACA);
        oracle.setRecipient(_user, FAKE_RECIPIENT);
        assertEq(oracle.recipient(_user), FAKE_RECIPIENT);
    }

    function testSetRecipientWrongAuth() public {
        address FAKE_RECIPIENT = address(0xCACA);

        // Random User
        vm.prank(address(0x1));
        vm.expectRevert(CurveGaugeControllerOracle.NOT_OWNER.selector);
        oracle.setRecipient(_user, FAKE_RECIPIENT);
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
        vm.expectRevert("UNAUTHORIZED");
        platform.whitelistAddress(_user, true);

        assertFalse(platform.whitelisted(_user));
    }

    function testSetBlockHash() public {
        // Create Default Bounty.
        _gaugeController.checkpoint_gauge(_gauge);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());
        // Get RLP Encoded proofs.
        (bytes32 _block_hash,,) = getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.setEthBlockHash(_blockNumber, _block_hash);

        assertEq(oracle.activePeriod(), _getCurrentPeriod());
    }

    function testSetBlockHashAlreadySet() public {
        // Create Default Bounty.
        _gaugeController.checkpoint_gauge(_gauge);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());
        // Get RLP Encoded proofs.
        (bytes32 _block_hash,,) = getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.setEthBlockHash(_blockNumber, _block_hash);

        assertEq(oracle.activePeriod(), _getCurrentPeriod());

        vm.expectRevert(CurveGaugeControllerOracle.PERIOD_ALREADY_UPDATED.selector);
        // Submit ETH Block Hash to Oracle.
        oracle.setEthBlockHash(_blockNumber, _block_hash);
    }

    function testSetBlockHashWithAxelar() public {
        // Create Default Bounty.
        _gaugeController.checkpoint_gauge(_gauge);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());
        // Get RLP Encoded proofs.
        (bytes32 _block_hash,,) = getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        assertEq(oracle.activePeriod(), 0);

        // Submit ETH Block Hash to Oracle.
        axelarExecutable.execute(
            "",
            "Ethereum",
            address(sender).toHexStringChecksumed(),
            abi.encodeWithSelector(CurveGaugeControllerOracle.setEthBlockHash.selector, _blockNumber, _block_hash)
        );

        assertEq(oracle.activePeriod(), _getCurrentPeriod());
    }

    function testClaimBribeWithWhitelistedRecipientNotSet() public {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _gaugeController.checkpoint_gauge(_gauge);

        skip(1 days);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());
        _blockNumber = 19730772; // Thursday (first day of period)

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.setEthBlockHash(_blockNumber, _block_hash);
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
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _gaugeController.checkpoint_gauge(_gauge);

        skip(1 days);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());
        _blockNumber = 19730772; // Thursday (first day of period)

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.setEthBlockHash(_blockNumber, _block_hash);

        address FAKE_RECIPIENT = address(0xCACA);
        oracle.setRecipient(_user, FAKE_RECIPIENT);

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

        assertGt(platform.rewardPerVote(_id), 0);

        claimed = platform.claim(_id, _proofData);
        assertEq(claimed, 0);
    }

    function testClaimBribeWithWhitelistedRecipientSet() public {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _gaugeController.checkpoint_gauge(_gauge);

        skip(1 days);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());
        _blockNumber = 19730772; // Thursday (first day of period)

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.setEthBlockHash(_blockNumber, _block_hash);

        platform.whitelistAddress(_user, true);

        address FAKE_RECIPIENT = address(0xCACA);
        oracle.setRecipient(_user, FAKE_RECIPIENT);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: _block_header_rlp,
            userProofRlp: _proof_rlp,
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

    function testClaimBribe() public {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _gaugeController.checkpoint_gauge(_gauge);

        skip(1 days);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());
        _blockNumber = 19730772; // Thursday (first day of period)

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.setEthBlockHash(_blockNumber, _block_hash);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: _block_header_rlp,
            userProofRlp: _proof_rlp,
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

    function testClaimable() public {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _gaugeController.checkpoint_gauge(_gauge);

        // Deploy a claimable platform

        skip(1 days);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());
        _blockNumber = 19730772; // Thursday (first day of period)

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.setEthBlockHash(_blockNumber, _block_hash);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: _block_header_rlp,
            userProofRlp: _proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        uint256 claimable = platform.claimable(_id, _proofData);
        uint256 claimableOnClaimable = platformClaimable.claimable(_id, _proofData);
        uint256 claimed = platform.claim(_id, _proofData);

        assertGt(claimed, 0);
        assertGt(claimable, 0);
        assertEq(claimable, claimableOnClaimable);
        assertApproxEqRel(claimed, claimable, 1e15);

        assertGt(platform.rewardPerVote(_id), 0);

        claimable = platform.claimable(_id, _proofData);
        claimableOnClaimable = platformClaimable.claimable(_id, _proofData);
        claimed = platform.claim(_id, _proofData);

        assertEq(claimable, 0);
        assertEq(claimed, 0);
        assertEq(claimableOnClaimable, 0);
    }
    function testClaimWithBlacklistedAddress() public {
        // Create Default Bounty.
        uint256 _id = _createDefaultBountyWithBlacklist(2 weeks);
        _gaugeController.checkpoint_gauge(_gauge);

        skip(1 days);

        // Calculate blacklisted bias before sending proof.
        uint256 _bBias = _gaugeController.vote_user_slopes(_blacklisted, _gauge).slope
            * (_gaugeController.vote_user_slopes(_blacklisted, _gauge).end - _getCurrentPeriod());

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());
        _blockNumber = 19730772; // Thursday (first day of period)

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Build the proof.
        (,,, _positions,) = sender.generateEthProofParams(_blacklisted, _gauge, _getCurrentPeriod());

        (,, bytes memory _blacklisted_proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.setEthBlockHash(_blockNumber, _block_hash);

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
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(3 weeks);
        _gaugeController.checkpoint_gauge(_gauge);

        // Build the proof.
        (,,, uint256[6] memory _positions, uint256 _blockNumber) =
            sender.generateEthProofParams(_user, _gauge, _getCurrentPeriod());
        _blockNumber = 19730772; // Thursday (first day of period)

        // Get RLP Encoded proofs.
        (bytes32 _block_hash, bytes memory _block_header_rlp, bytes memory _proof_rlp) =
            getRLPEncodedProofs("mainnet", address(_gaugeController), _positions, _blockNumber);

        // Submit ETH Block Hash to Oracle.
        oracle.setEthBlockHash(_blockNumber, _block_hash);

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
        platform.closeBounty(_id);
        assertEq(rewardToken.balanceOf(_user), 0);
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

    function _createDefaultBounty(uint256 numberOfWeeks) internal returns (uint256 _id) {
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
