// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

import "test/utils/Utils.sol";
import {IAxelarGateway} from "src/interfaces/IAxelarGateway.sol";
import {IAxelarGasReceiverProxy} from "src/interfaces/IAxelarGasReceiverProxy.sol";
import {BnbGaugeVotingStateSender} from "src/BnbGaugeVotingStateSender.sol";
import {IPlatform} from "src/interfaces/IPlatform.sol";
import {IGaugeVoting} from "src/interfaces/IGaugeVoting.sol";
import {AxelarExecutableClaimer} from "src/AxelarExecutableClaimer.sol";
import {MockPancakePlatform} from "test/mocks/MockPancakePlatform.sol";

contract BnbGaugeVotingStateSenderTest is Utils {
    BnbGaugeVotingStateSender internal sender;
    AxelarExecutableClaimer internal claimer;
    MockPancakePlatform internal platform;

    struct ClaimData {
        address user;
        uint256 lastVote;
        uint256 gaugeBias;
        uint256 gaugeSlope;
        uint256 userVoteSlope;
        uint256 userVotePower;
        uint256 userVoteEnd;
    }

    address internal constant USER = 0xb3C97eEA5900E8A620434d7E3A954dA512df7593; // locker + proxy expired
    address internal constant USER_2 = 0x2dDd6fAb33eA2395A17C061533972E449a38A3c2; // locker + proxy
    address internal constant USER_2_PROXY = 0xdf29565f309797e101a553471804073399242D71;
    address internal constant GAUGE = 0x6425bC30D0751aF5181fC74a50e760b0e4a19811;
    address internal constant GAUGE_2 = 0x9cac9745731d1Cf2B483f257745A512f0938DD01;
    address internal constant GAUGE_VOTING = 0xf81953dC234cdEf1D6D0d3ef61b232C6bCbF9aeF;
    uint256 internal constant GAUGE_CHAIN_ID = 56;
    uint256 internal constant DST_CHAIN_ID = 42161;

    function setUp() public {
        uint256 forkId = vm.createFork("bsc", 41162000);
        vm.selectFork(forkId);

        // deploy all contracts in the same chain
        sender = new BnbGaugeVotingStateSender(address(this), 0.003 ether, 0.001 ether);

        platform = new MockPancakePlatform();

        claimer = new AxelarExecutableClaimer(sender.AXELAR_GATEWAY(), address(sender), "binance", address(platform));

        sender.setVm(address(claimer), "arbitrum", DST_CHAIN_ID);
    }

    function testSendClaimStateWithoutProxy() external {
        address[] memory blacklist;

        vm.recordLogs();

        sender.claimOnDstChain{value: sender.claimMinValue()}(0, USER, GAUGE, GAUGE_CHAIN_ID, DST_CHAIN_ID, blacklist);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        (,, bytes memory payload) = abi.decode(entries[1].data, (string, string, bytes));

        (uint256 gaugeBias, IPlatform.ClaimData[] memory claimData) = this._encodePayload(payload);

        // check gauge data
        assertGt(gaugeBias, 0);
        assertEq(claimData.length, 1);

        uint256 currentPeriod = getCurrentPeriod();

        bytes32 gaugeHash = keccak256(abi.encodePacked(GAUGE, GAUGE_CHAIN_ID));

        uint256 lastVote = IGaugeVoting(GAUGE_VOTING).lastUserVote(USER, gaugeHash);

        IGaugeVoting.VotedSlope memory userVotedSlope = IGaugeVoting(GAUGE_VOTING).voteUserSlopes(USER, gaugeHash);
        uint256 userVoteBias = userVotedSlope.slope * (userVotedSlope.end - currentPeriod);

        // check user data
        assertEq(claimData[0].user, USER);
        assertGt(claimData[0].lastVote, 0);
        assertEq(claimData[0].lastVote, lastVote);
        assertGt(claimData[0].lastVote, currentPeriod);
        assertGt(claimData[0].userVoteBias, 0);
        assertEq(claimData[0].userVoteBias, userVoteBias);

        (bool success,) = address(platform).call(payload);
        assertTrue(success);
    }

    function testSendClaimStateWithProxy() external {
        address[] memory blacklist;

        vm.recordLogs();

        sender.claimOnDstChain{value: sender.claimMinValue()}(
            0, USER_2, GAUGE_2, GAUGE_CHAIN_ID, DST_CHAIN_ID, blacklist
        );

        Vm.Log[] memory entries = vm.getRecordedLogs();

        (,, bytes memory payload) = abi.decode(entries[1].data, (string, string, bytes));

        (uint256 gaugeBias, IPlatform.ClaimData[] memory claimData) = this._encodePayload(payload);

        // check gauge bias
        assertGt(gaugeBias, 0);
        assertEq(claimData.length, 1);

        bytes32 gaugeHash = keccak256(abi.encodePacked(GAUGE_2, GAUGE_CHAIN_ID));
        uint256 userLastVote = IGaugeVoting(GAUGE_VOTING).lastUserVote(USER_2, gaugeHash);
        uint256 proxyLastVote = IGaugeVoting(GAUGE_VOTING).lastUserVote(USER_2_PROXY, gaugeHash);

        uint256 currentPeriod = getCurrentPeriod();

        IGaugeVoting.VotedSlope memory userVotedSlope = IGaugeVoting(GAUGE_VOTING).voteUserSlopes(USER_2, gaugeHash);
        uint256 userVoteBias = userVotedSlope.slope * (userVotedSlope.end - currentPeriod);

        IGaugeVoting.VotedSlope memory proxyVotedSlope =
            IGaugeVoting(GAUGE_VOTING).voteUserSlopes(USER_2_PROXY, gaugeHash);
        uint256 proxyVoteBias = proxyVotedSlope.slope * (proxyVotedSlope.end - currentPeriod);

        // check user+proxy data
        assertEq(claimData[0].user, USER_2);
        assertGt(claimData[0].lastVote, 0);
        assertGt(claimData[0].lastVote, currentPeriod);
        assertEq(userLastVote, proxyLastVote);
        assertEq(claimData[0].lastVote, userLastVote);
        assertGt(claimData[0].userVoteBias, 0);
        assertEq(claimData[0].userVoteBias, userVoteBias + proxyVoteBias);

        (bool success,) = address(platform).call(payload);
        assertTrue(success);
    }

    function testSendClaimStateWithoutLockAndWithouProxy() external {
        address user = address(0xABCD);

        address[] memory blacklist;

        uint256 minValue = sender.claimMinValue();

        vm.expectRevert(BnbGaugeVotingStateSender.UserWithoutBias.selector);
        sender.claimOnDstChain{value: minValue}(0, user, GAUGE_2, GAUGE_CHAIN_ID, DST_CHAIN_ID, blacklist);
    }

    function testSendClaimStateWithBlacklist() external {
        address[] memory blacklist = new address[](1);
        blacklist[0] = USER;

        vm.recordLogs();

        sender.claimOnDstChain{value: sender.claimMinValue()}(
            0, USER_2, GAUGE_2, GAUGE_CHAIN_ID, DST_CHAIN_ID, blacklist
        );

        Vm.Log[] memory entries = vm.getRecordedLogs();

        (,, bytes memory payload) = abi.decode(entries[1].data, (string, string, bytes));

        (, IPlatform.ClaimData[] memory claimData) = this._encodePayload(payload);

        // user+proxy
        // blacklist user 1
        assertEq(claimData.length, 2);

        assertEq(claimData[1].user, USER);
    }

    function testSendClaimStateWithProxyInBlacklist() external {
        address[] memory blacklist = new address[](1);
        blacklist[0] = USER_2_PROXY;

        vm.recordLogs();

        sender.claimOnDstChain{value: sender.claimMinValue()}(
            0, USER_2, GAUGE_2, GAUGE_CHAIN_ID, DST_CHAIN_ID, blacklist
        );

        Vm.Log[] memory entries = vm.getRecordedLogs();

        (,, bytes memory payload) = abi.decode(entries[1].data, (string, string, bytes));

        (, IPlatform.ClaimData[] memory claimData) = this._encodePayload(payload);

        // user+proxy
        assertEq(claimData[0].user, USER_2);

        // blacklist user 2 proxy
        assertEq(claimData.length, 2);
        assertEq(claimData[1].user, USER_2_PROXY);
        assertEq(claimData[1].userVoteBias, 0);
        assertEq(claimData[1].lastVote, 0);
    }

    function testDisableVm() external {
        // disable arbitrum as votemarket dst chain
        sender.setVm(address(0), "arbitrum", DST_CHAIN_ID);
        address[] memory blacklist;

        vm.recordLogs();

        sender.claimOnDstChain{value: sender.claimMinValue()}(
            0, USER_2, GAUGE_2, GAUGE_CHAIN_ID, DST_CHAIN_ID, blacklist
        );

        Vm.Log[] memory entries = vm.getRecordedLogs();

        // no events emitted
        assertEq(entries.length, 0);
    }

    function testSetRecipient() external {
        address recipient = address(0xABCD);

        vm.recordLogs();

        sender.setRecipient{value: sender.setRecipientMinValue()}(DST_CHAIN_ID, recipient);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        (,, bytes memory payload) = abi.decode(entries[1].data, (string, string, bytes));

        (address _user, address _recipient) = this._encodePayloadSetRecipient(payload);

        assertEq(address(this), _user);
        assertEq(recipient, _recipient);
    }

    function _encodePayload(bytes calldata _payload)
        public
        pure
        returns (uint256 gaugeBias, IPlatform.ClaimData[] memory claimData)
    {
        (,,, gaugeBias, claimData) =
            abi.decode(_payload[4:], (uint256, address, uint256, uint256, IPlatform.ClaimData[]));
    }

    function _encodePayloadSetRecipient(bytes calldata _payload)
        public
        pure
        returns (address user, address recipient)
    {
        (user, recipient) = abi.decode(_payload[4:], (address, address));
    }

    function getCurrentPeriod() public view returns (uint256) {
        return (block.timestamp / 1 weeks) * 1 weeks;
    }
}
