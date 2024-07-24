// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Platform} from "src/pancakeswap/Platform.sol";
import {LibString} from "solady/utils/LibString.sol";
import {AxelarExecutable} from "src/AxelarExecutable.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {GaugeController} from "src/interfaces/GaugeController.sol";
import {BnbStateSender} from "src/BnbStateSender.sol";
import {BaseGaugeControllerOracle} from "src/oracles/BaseGaugeControllerOracle.sol";
import {PancakeOracle} from "src/oracles/PancakeOracle.sol";
import {BasePlatformTest} from "test/integration/BasePlatformTest.sol";

contract PancakePlatformTest is BasePlatformTest {
    using LibString for address;

    Platform internal pancakePlatform;
    uint256 internal chainId;
    address internal _user_proxy;
    BnbStateSender internal bnbSender;

    function setUp() public override {
        blockNumber = 40518620; // 16 jul tuesday
        startPeriodBlockNumber = 40698462; // 22 jul proof block number
        forkRpc = "bsc";
        chainId = 56;

        super.setUp();

        _user = 0x2dDd6fAb33eA2395A17C061533972E449a38A3c2;
        _user_proxy = 0xdf29565f309797e101a553471804073399242D71; // (proxy)
        _gauge = 0x9cac9745731d1Cf2B483f257745A512f0938DD01;
        _blacklisted = address(0xAABB);
        _deployer = 0x0dE5199779b43E13B3Bec21e91117E18736BC1A8;

        _gaugeController = GaugeController(0xf81953dC234cdEf1D6D0d3ef61b232C6bCbF9aeF);

        bnbSender = new BnbStateSender(_deployer, 0.003 ether, 0.001 ether);

        oracles = new address[](2);
        oracles[0] = address(new PancakeOracle(address(axelarExecutable), address(_gaugeController)));
        oracles[1] = address(new PancakeOracle(address(axelarExecutable), address(_gaugeController)));

        axelarExecutable = new AxelarExecutable(address(_gateway), address(sender), oracles);

        PancakeOracle(oracles[0]).setAxelarExecutable(address(axelarExecutable));
        PancakeOracle(oracles[1]).setAxelarExecutable(address(axelarExecutable));

        pancakePlatform = new Platform(address(oracles[0]), address(this), address(this));

        rewardToken.mint(address(this), _amount);
        rewardToken.approve(address(pancakePlatform), _amount);
    }

    function testSetBlockHash() public override {
        // test the call
        _generateBscProofParams(_user, _gauge, chainId, _getCurrentPeriod());

        // Submit ETH Block Hash to Oracle.
        PancakeOracle(oracles[0]).setEthBlockHash(block.number, blockhash(block.number));

        assertEq(PancakeOracle(oracles[0]).activePeriod(), _getCurrentPeriod());
    }

    function testSetBlockHashAlreadySet() public override {
        // Submit ETH Block Hash to Oracle.
        PancakeOracle(oracles[0]).setEthBlockHash(block.number, blockhash(block.number));

        assertEq(PancakeOracle(oracles[0]).activePeriod(), _getCurrentPeriod());

        vm.expectRevert(BaseGaugeControllerOracle.PERIOD_ALREADY_UPDATED.selector);
        // Submit ETH Block Hash to Oracle.
        PancakeOracle(oracles[0]).setEthBlockHash(block.number, blockhash(block.number));
    }

    function testSetBlockHashWithAxelar() public override {
        assertEq(PancakeOracle(oracles[0]).activePeriod(), 0);

        // Submit ETH Block Hash to Oracle.
        axelarExecutable.execute(
            "",
            "Bsc",
            address(sender).toHexStringChecksumed(),
            abi.encodeWithSelector(
                BaseGaugeControllerOracle.setEthBlockHash.selector, block.number, blockhash(block.number)
            )
        );

        assertEq(PancakeOracle(oracles[0]).activePeriod(), _getCurrentPeriod());
    }

    function testMultipleOraclesReceivePayload() public override {
        assertEq(BaseGaugeControllerOracle(oracles[0]).activePeriod(), 0);
        assertEq(BaseGaugeControllerOracle(oracles[1]).activePeriod(), 0);

        // Submit ETH Block Hash to Oracle.
        axelarExecutable.execute(
            "",
            "Bsc",
            address(sender).toHexStringChecksumed(),
            abi.encodeWithSelector(
                BaseGaugeControllerOracle.setEthBlockHash.selector, block.number, blockhash(block.number)
            )
        );

        assertEq(BaseGaugeControllerOracle(oracles[0]).activePeriod(), _getCurrentPeriod());
        assertEq(BaseGaugeControllerOracle(oracles[1]).activePeriod(), _getCurrentPeriod());
    }

    function testWhitelist() public override {
        pancakePlatform.whitelistAddress(_user, true);
        assertTrue(pancakePlatform.whitelisted(_user));

        pancakePlatform.whitelistAddress(_user, false);
        assertFalse(pancakePlatform.whitelisted(_user));
    }

    function testWhitelistWrongAuth() public override {
        // Random User
        vm.prank(address(0x1));
        vm.expectRevert("UNAUTHORIZED");
        pancakePlatform.whitelistAddress(_user, true);

        assertFalse(pancakePlatform.whitelisted(_user));
    }

    function testClaimable() public override {
        // Create Default Bounty.
        // 16 July (Tuesday)
        uint256 _id = _createDefaultBounty(1 weeks);
        _checkpointGauge(_gauge);

        skip(6 days);

        // 22 July

        (bytes32 _blockHash, bytes memory block_header_rlp, bytes memory proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), startPeriodBlockNumber, vm.toString(_user));

        // Submit ETH Block Hash to Oracle.
        BaseGaugeControllerOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, _blockHash);

        // No need to submit it.
        Platform.ProofData memory _userVoteProof = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        Platform.ProofData memory _proxyVoteProof = Platform.ProofData({
            user: address(0),
            headerRlp: "0x",
            userProofRlp: "0x",
            blackListedProofsRlp: new bytes[](0)
        });

        Platform.ProofData memory _proxyOwnerProof = Platform.ProofData({
            user: address(0),
            headerRlp: "0x",
            userProofRlp: "0x",
            blackListedProofsRlp: new bytes[](0)
        });

        uint256 claimable = pancakePlatform.claimable(_id, _userVoteProof, _proxyVoteProof);
        vm.prank(_user);
        uint256 claimed = pancakePlatform.claim(_id, _userVoteProof, _proxyVoteProof, _proxyOwnerProof);

        assertGt(claimed, 0);
        assertGt(claimable, 0);
        assertApproxEqRel(claimed, claimable, 1e15);

        assertGt(pancakePlatform.rewardPerVote(_id), 0);

        claimable = pancakePlatform.claimable(_id, _userVoteProof, _proxyVoteProof);
        vm.prank(_user);
        claimed = pancakePlatform.claim(_id, _userVoteProof, _proxyVoteProof, _proxyOwnerProof);

        assertEq(claimable, 0);
        assertEq(claimed, 0);
    }

    function testClaimableWithProxy() public {
        uint256 _id = _createDefaultBounty(1 weeks);
        _checkpointGauge(_gauge);

        skip(6 days);

        (bytes32 _blockHash, bytes memory block_header_rlp, bytes memory user_proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), startPeriodBlockNumber, vm.toString(_user));

        (,, bytes memory proxy_proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), startPeriodBlockNumber, vm.toString(_user_proxy));

        // Submit ETH Block Hash to Oracle.
        BaseGaugeControllerOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, _blockHash);

        Platform.ProofData memory _userVoteProof = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: user_proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        Platform.ProofData memory _proxyVoteProof = Platform.ProofData({
            user: _user_proxy,
            headerRlp: block_header_rlp,
            userProofRlp: proxy_proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        uint256 claimable = pancakePlatform.claimable(_id, _userVoteProof);
        assertGt(claimable, 0);

        uint256 claimableWithProxy = pancakePlatform.claimable(_id, _userVoteProof, _proxyVoteProof);
        assertGt(claimableWithProxy, 0);
        assertGt(claimableWithProxy, claimable);
    }

    function testClaimBribeWithWhitelistedRecipientNotSet() public override {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _checkpointGauge(_gauge);

        skip(8 days);

        (bytes32 _blockHash, bytes memory block_header_rlp, bytes memory proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), startPeriodBlockNumber, vm.toString(_user));

        // Submit ETH Block Hash to Oracle.
        BaseGaugeControllerOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, _blockHash);
        pancakePlatform.whitelistAddress(_user, true);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        vm.expectRevert(Platform.NO_RECEIVER_SET_FOR_WHITELISTED.selector);
        pancakePlatform.claim(_id, _proofData);
    }

    function testClaimBribeWithRecipientSet() public override {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _checkpointGauge(_gauge);

        skip(8 days);

        (bytes32 _blockHash, bytes memory block_header_rlp, bytes memory proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), startPeriodBlockNumber, vm.toString(_user));

        // Submit ETH Block Hash to Oracle.
        PancakeOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, _blockHash);

        address FAKE_RECIPIENT = address(0xCACA);
        PancakeOracle(oracles[0]).setRecipient(_user, FAKE_RECIPIENT);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        vm.prank(_user);
        uint256 claimed = pancakePlatform.claim(_id, _proofData);

        assertGt(claimed, 0);

        assertEq(rewardToken.balanceOf(_user), 0);
        assertEq(rewardToken.balanceOf(FAKE_RECIPIENT), claimed);

        assertGt(pancakePlatform.rewardPerVote(_id), 0);

        vm.prank(_user);
        claimed = pancakePlatform.claim(_id, _proofData);
        assertEq(claimed, 0);
    }

    function testClaimBribeWithWhitelistedRecipientSet() public override {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _checkpointGauge(_gauge);

        skip(8 days);

        // Build the proof.
        (bytes32 _blockHash, bytes memory block_header_rlp, bytes memory proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), startPeriodBlockNumber, vm.toString(_user));

        // Submit ETH Block Hash to Oracle.
        PancakeOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, _blockHash);

        pancakePlatform.whitelistAddress(_user, true);

        address FAKE_RECIPIENT = address(0xCACA);
        PancakeOracle(oracles[0]).setRecipient(_user, FAKE_RECIPIENT);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        uint256 claimable = pancakePlatform.claimable(_id, _proofData);
        vm.prank(_user);
        uint256 claimed = pancakePlatform.claim(_id, _proofData);

        assertGt(claimed, 0);
        assertGt(claimable, 0);
        assertApproxEqRel(claimed, claimable, 1e15);

        assertEq(rewardToken.balanceOf(_user), 0);
        assertEq(rewardToken.balanceOf(FAKE_RECIPIENT), claimed);

        assertGt(pancakePlatform.rewardPerVote(_id), 0);

        vm.prank(_user);
        claimed = pancakePlatform.claim(_id, _proofData);
        claimable = pancakePlatform.claimable(_id, _proofData);

        assertEq(claimed, 0);
        assertEq(claimable, 0);
    }

    function testClaimBribe() public override {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _checkpointGauge(_gauge);

        skip(8 days);

        // Build the proof.
        (bytes32 _blockHash, bytes memory block_header_rlp, bytes memory proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), startPeriodBlockNumber, vm.toString(_user));

        // Submit ETH Block Hash to Oracle.
        PancakeOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, _blockHash);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        uint256 claimable = pancakePlatform.claimable(_id, _proofData);

        vm.prank(_user);
        uint256 claimed = pancakePlatform.claim(_id, _proofData);

        assertGt(claimed, 0);
        assertGt(claimable, 0);
        assertApproxEqRel(claimed, claimable, 1e15);

        assertGt(pancakePlatform.rewardPerVote(_id), 0);

        claimable = pancakePlatform.claimable(_id, _proofData);
        vm.prank(_user);
        claimed = pancakePlatform.claim(_id, _proofData);

        assertEq(claimable, 0);
        assertEq(claimed, 0);
    }

    function testClaimBribeWithProxy() public {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _checkpointGauge(_gauge);

        skip(8 days);

        // Build the proof.
        (bytes32 _blockHash, bytes memory block_header_rlp, bytes memory user_proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), startPeriodBlockNumber, vm.toString(_user));

        (,, bytes memory proxy_proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), startPeriodBlockNumber, vm.toString(_user_proxy));

        (, bytes memory block_header_owner_rlp, bytes memory proxy_owner_proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), 40719951, "proxyOwnership");

        // Submit ETH Block Hash to Oracle.
        PancakeOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, _blockHash);

        Platform.ProofData memory _userProofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: user_proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        Platform.ProofData memory _proxyProofData = Platform.ProofData({
            user: _user_proxy,
            headerRlp: block_header_rlp,
            userProofRlp: proxy_proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        Platform.ProofData memory _proxyOwnerProofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_owner_rlp,
            userProofRlp: proxy_owner_proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        vm.prank(_user);
        uint256 claimed = pancakePlatform.claim(_id, _userProofData, _proxyProofData, _proxyOwnerProofData);
        assertGt(claimed, 0);
    }

    function testClaimBribeWithProxySet() public {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _checkpointGauge(_gauge);

        skip(8 days);

        // Build the proof.
        (bytes32 _blockHash, bytes memory block_header_rlp, bytes memory user_proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), startPeriodBlockNumber, vm.toString(_user));

        (,, bytes memory proxy_proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), startPeriodBlockNumber, vm.toString(_user_proxy));

        (, bytes memory block_header_owner_rlp, bytes memory proxy_owner_proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), 40719951, "proxyOwnership");

        // Submit ETH Block Hash to Oracle.
        PancakeOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, _blockHash);

        // Submit user's proxy ownership proof before claiming
        PancakeOracle(oracles[0]).submitProxyOwnershipProof(_user, block_header_owner_rlp, proxy_owner_proof_rlp);

        Platform.ProofData memory _userProofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: user_proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        Platform.ProofData memory _proxyProofData = Platform.ProofData({
            user: _user_proxy,
            headerRlp: block_header_rlp,
            userProofRlp: proxy_proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        vm.prank(_user);
        uint256 claimed = pancakePlatform.claim(_id, _userProofData, _proxyProofData);
        assertGt(claimed, 0);
    }

    function testClaimBribeWithOnlyProxy() public {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(1 weeks);
        _checkpointGauge(_gauge);

        skip(8 days);

        // Build the proof.
        (bytes32 _blockHash, bytes memory block_header_rlp, bytes memory user_proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), startPeriodBlockNumber, vm.toString(_user));

        (,, bytes memory proxy_proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), startPeriodBlockNumber, vm.toString(_user_proxy));

        (, bytes memory block_header_owner_rlp, bytes memory proxy_owner_proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), 40719951, "proxyOwnership");

        // Submit ETH Block Hash to Oracle.
        PancakeOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, _blockHash);

        Platform.ProofData memory _userProofData =
            Platform.ProofData({user: _user, headerRlp: "", userProofRlp: "", blackListedProofsRlp: new bytes[](0)});

        Platform.ProofData memory _proxyProofData = Platform.ProofData({
            user: _user_proxy,
            headerRlp: block_header_rlp,
            userProofRlp: proxy_proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        Platform.ProofData memory _proxyOwnerProofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_owner_rlp,
            userProofRlp: proxy_owner_proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        vm.prank(_user);
        // claim with only proxy proof
        uint256 claimed = pancakePlatform.claim(_id, _userProofData, _proxyProofData, _proxyOwnerProofData);
        assertGt(claimed, 0);

        _userProofData.headerRlp = block_header_rlp;
        _userProofData.userProofRlp = user_proof_rlp;
        // claim with only user proof
        claimed = pancakePlatform.claim(_id, _userProofData);
        assertGt(claimed, 0);
    }

    function testCloseBribe() public override {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(3 weeks);
        _checkpointGauge(_gauge);

        // Build the proof.
        (bytes32 _blockHash, bytes memory block_header_rlp, bytes memory proof_rlp) =
            getRLPEncodedProofsBsc(vm.rpcUrl("bsc"), startPeriodBlockNumber, vm.toString(_user));

        // Submit ETH Block Hash to Oracle.
        PancakeOracle(oracles[0]).setEthBlockHash(startPeriodBlockNumber, _blockHash);

        // No need to submit it.
        Platform.ProofData memory _proofData = Platform.ProofData({
            user: _user,
            headerRlp: block_header_rlp,
            userProofRlp: proof_rlp,
            blackListedProofsRlp: new bytes[](0)
        });

        vm.prank(_user);
        uint256 claimed = pancakePlatform.claim(_id, _proofData);
        assertEq(claimed, 0);

        vm.prank(_user);
        pancakePlatform.closeBounty(_id);
        assertEq(rewardToken.balanceOf(_user), 0);
    }

    function testClaimMultipleTimes() public override {}

    function testClaimWithBlacklistedAddress() public override {}

    function _createDefaultBounty(uint256 numberOfWeeks) internal override returns (uint256 _id) {
        _id = pancakePlatform.createBounty(
            _gauge, chainId, _user, address(rewardToken), uint8(numberOfWeeks), 2e18, _amount, new address[](0), true
        );
    }

    function _checkpointGauge(address _gauge) internal override {
        _gaugeController.checkpointGauge(_gauge, chainId);
    }

    function _generateBscProofParams(address _user, address _gauge, uint256 _chainId, uint256 _time)
        internal
        pure
        returns (address, address, uint256, uint256[6] memory _positions)
    {
        bytes32 gaugeHash = keccak256(abi.encodePacked(_gauge, _chainId));
        uint256 lastUserVotePosition =
            uint256(keccak256(abi.encode(gaugeHash, keccak256(abi.encode(_user, 6000000011)))));
        _positions[0] = lastUserVotePosition;
        uint256 pointWeightsPosition =
            uint256(keccak256(abi.encode(_time, keccak256(abi.encode(gaugeHash, 6000000014)))));
        uint256 i;
        for (i = 0; i < 2; i++) {
            _positions[1 + i] = pointWeightsPosition + i;
        }

        uint256 voteUserSlopePosition =
            uint256(keccak256(abi.encode(gaugeHash, keccak256(abi.encode(_user, 6000000009)))));
        for (i = 0; i < 3; i++) {
            _positions[3 + i] = voteUserSlopePosition + i;
        }
        return (_user, _gauge, _time, _positions);
    }

    function _generateBscProxyOwnerProofParams(address _user) internal pure returns (uint256 _position) {
        _position = uint256(keccak256(abi.encode(_user, 8)));
    }
}
