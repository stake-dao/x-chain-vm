// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "test/utils/Utils.sol";

import {PlatformNoProof} from "src/pancakeswap/PlatformNoProof.sol";
import {IPlatformNoProof} from "src/interfaces/IPlatformNoProof.sol";
import {LibString} from "solady/utils/LibString.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {GaugeController} from "src/interfaces/GaugeController.sol";
import {BnbGaugeVotingStateSender} from "src/BnbGaugeVotingStateSender.sol";
import {AxelarExecutableClaimer} from "src/AxelarExecutableClaimer.sol";
import {BasePlatformTest} from "test/integration/BasePlatformTest.sol";

contract PancakePlatformTest is BasePlatformTest {
    using LibString for address;

    PlatformNoProof internal pancakePlatform;
    uint256 internal chainId;
    address internal _user_proxy;
    BnbGaugeVotingStateSender internal bnbSender;
    AxelarExecutableClaimer internal claimer;

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

        bnbSender = new BnbGaugeVotingStateSender(_deployer, 0.003 ether, 0.001 ether);

        claimer = new AxelarExecutableClaimer(address(_gateway), address(bnbSender), "binance", address(0));

        pancakePlatform = new PlatformNoProof(_deployer, _deployer, address(claimer));

        claimer.transferOwnership(_deployer);

        vm.startPrank(_deployer);
        bnbSender.setVm(address(claimer), "binance", chainId);
        claimer.setPlatform(address(pancakePlatform));
        vm.stopPrank();

        rewardToken.mint(address(this), _amount);
        rewardToken.approve(address(pancakePlatform), _amount);
    }

    function testSetBlockHash() public override {}

    function testSetBlockHashAlreadySet() public override {}

    function testSetBlockHashWithAxelar() public override {}

    function testSetRecipientWithClaimer() public {
        address recipient = address(0xABCD);
        claimer.execute("", "binance", address(bnbSender).toHexStringChecksumed(), abi.encodeWithSelector(PlatformNoProof.setRecipient.selector, address(this), recipient));

        assertEq(pancakePlatform.recipient(address(this)), recipient);
    }

    function testMultipleOraclesReceivePayload() public override {}

    function testWhitelist() public override {
        vm.prank(_deployer);
        pancakePlatform.whitelistAddress(_user, true);
        assertTrue(pancakePlatform.whitelisted(_user));

        vm.prank(_deployer);
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

    function testClaimableWithProxy() public {
        // Create Default Bounty.
        // 16 July (Tuesday)
        uint256 _id = _createDefaultBounty(3);
        _checkpointGauge(_gauge);
        
        skip(6 days);
        
        // 22 July

        // simulate state sender to create claim data for user
        address[] memory blacklist;

        bytes memory payload = _createClaimPayload(_id, _user, _gauge, chainId, blacklist); 

        (uint256 gaugeBias, IPlatformNoProof.ClaimData[] memory claimData) = this._encodePayload(payload);
        assertEq(claimData.length, 2);

        // check claimable amount
        IPlatformNoProof.ClaimData[] memory blacklistClaimData;
        uint256 claimable = pancakePlatform.claimable(_id, gaugeBias, claimData[0], claimData[1], blacklistClaimData);
        assertGt(claimable, 0);

        // trigger the execute on the claimer
        uint256 snapshotBalance = rewardToken.balanceOf(_user);
        claimer.execute("", "binance", address(bnbSender).toHexStringChecksumed(), payload);
        uint256 balanceAfterFirstClaim = rewardToken.balanceOf(_user);

        assertGt(pancakePlatform.rewardPerVote(_id), 0);

        assertGt(balanceAfterFirstClaim, snapshotBalance);
        assertApproxEqAbs(claimable, balanceAfterFirstClaim - snapshotBalance, 1);

        claimable = pancakePlatform.claimable(_id, gaugeBias, claimData[0], claimData[1], blacklistClaimData);
        assertEq(claimable, 0);

        claimer.execute("", "binance", address(bnbSender).toHexStringChecksumed(), payload);
        uint256 balanceAfterSecondClaim = rewardToken.balanceOf(_user);

        assertGt(pancakePlatform.rewardPerVote(_id), 0);
        assertEq(balanceAfterFirstClaim, balanceAfterSecondClaim);
    }

    function testClaimable() public override {}

    function testClaimBribeWithWhitelistedRecipientNotSet() public override {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(3);
        _checkpointGauge(_gauge);

        vm.prank(_deployer);
        pancakePlatform.whitelistAddress(_user, true);
        
        skip(8 days);

        address[] memory blacklist;

        bytes memory payload = _createClaimPayload(_id, _user, _gauge, chainId, blacklist);

        vm.expectRevert(AxelarExecutableClaimer.CALL_FAILED.selector);
        claimer.execute("", "binance", address(bnbSender).toHexStringChecksumed(), payload);

        address recipient = address(0xABCD);
        claimer.execute("", "binance", address(bnbSender).toHexStringChecksumed(), abi.encodeWithSelector(PlatformNoProof.setRecipient.selector, _user, recipient));

        claimer.execute("", "binance", address(bnbSender).toHexStringChecksumed(), payload);
    }

    function testClaimBribeWithRecipientSet() public override {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(3);
        _checkpointGauge(_gauge);

        vm.prank(_deployer);
        pancakePlatform.whitelistAddress(_user, true);
        
        skip(8 days);

        address[] memory blacklist;

        bytes memory payload = _createClaimPayload(_id, _user, _gauge, chainId, blacklist);

        address recipient = address(0xABCD);
        claimer.execute("", "binance", address(bnbSender).toHexStringChecksumed(), abi.encodeWithSelector(PlatformNoProof.setRecipient.selector, _user, recipient));

        uint256 recipientSnapshot = rewardToken.balanceOf(recipient);
        claimer.execute("", "binance", address(bnbSender).toHexStringChecksumed(), payload);
        uint256 recipientBalanceAfterClaim = rewardToken.balanceOf(recipient);

        assertGt(recipientBalanceAfterClaim, recipientSnapshot);
    }

    function testClaimBribeWithWhitelistedRecipientSet() public override {}

    function testClaimBribe() public override {}

    function testClaimBribeWithProxy() public {}

    function testClaimBribeWithProxySet() public {}

    function testClaimBribeWithOnlyProxy() public {}

    function testCloseBribe() public override {
        // Create Default Bounty.
        uint256 _id = _createDefaultBounty(3);
        _checkpointGauge(_gauge);

        PlatformNoProof.Bounty memory bounty = pancakePlatform.getBounty(_id);

        pancakePlatform.closeBounty(_id);

        PlatformNoProof.Bounty memory bountyNotClosed = pancakePlatform.getBounty(_id);

        assertEq(bounty.manager, bountyNotClosed.manager);

        skip(bounty.endTimestamp - block.timestamp + 1);

        pancakePlatform.closeBounty(_id);

        PlatformNoProof.Bounty memory bountyClosed = pancakePlatform.getBounty(_id);

        assertEq(bountyClosed.manager, address(0));
    }

    function testSetRecipient() public override {}

    function testSetRecipientWrongAuth() public override {}

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

    function _createClaimPayload(uint256 _bountyId, address user, address gauge, uint256 _chainId, address[] memory _blacklist) internal returns (bytes memory _payload) {
        vm.recordLogs();

        bnbSender.claimOnDstChain{value: bnbSender.claimMinValue()}(_bountyId, user, gauge, _chainId, _chainId, _blacklist);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        (,, _payload) = abi.decode(entries[1].data, (string, string, bytes));
    }

    function _encodePayload(bytes calldata _payload)
        public
        pure
        returns (uint256 gaugeBias, IPlatformNoProof.ClaimData[] memory claimData)
    {
        (,,,, gaugeBias, claimData,) =
            abi.decode(_payload[4:], (uint256, address, address, uint256, uint256, IPlatformNoProof.ClaimData[], bool));
    }
}
