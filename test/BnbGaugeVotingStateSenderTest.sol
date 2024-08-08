// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.19;

import "test/utils/Utils.sol";
import {IAxelarGateway} from "src/interfaces/IAxelarGateway.sol";
import {IAxelarGasReceiverProxy} from "src/interfaces/IAxelarGasReceiverProxy.sol";
import {BnbGaugeVotingStateSender} from "src/BnbGaugeVotingStateSender.sol";
import {IPlatformNoProof} from "src/interfaces/IPlatformNoProof.sol";
import {AxelarExecutableClaimer} from "src/AxelarExecutableClaimer.sol";
import {MockPancakePlatformNoProof} from "test/mocks/MockPancakePlatformNoProof.sol";

contract BnbGaugeVotingStateSenderTest is Utils {
    BnbGaugeVotingStateSender internal sender;
    AxelarExecutableClaimer internal claimer;
    MockPancakePlatformNoProof internal platform;

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
    uint256 internal constant GAUGE_CHAIN_ID = 56;
    uint256 internal constant DST_CHAIN_ID = 42161;

    function setUp() public {
        uint256 forkId = vm.createFork("bsc", 41162000);
        vm.selectFork(forkId);

        // deploy all contracts in the same chain
        sender = new BnbGaugeVotingStateSender(address(this), 0.003 ether, 0.001 ether);

        platform = new MockPancakePlatformNoProof();

        claimer = new AxelarExecutableClaimer(sender.AXELAR_GATEWAY(), address(sender), "binance", address(platform));

        sender.setVm(address(claimer), "arbitrum", DST_CHAIN_ID);
    }

    function testSendClaimStateWithoutProxy() external {
        address[] memory blacklist;

        vm.recordLogs();

        sender.claimOnDstChain(0, USER, GAUGE, GAUGE_CHAIN_ID, DST_CHAIN_ID, blacklist);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        (,, bytes memory payload) = abi.decode(entries[1].data, (string, string, bytes));

        (
            uint256 gaugeBias,
            IPlatformNoProof.ClaimData memory userClaimData,
            IPlatformNoProof.ClaimData memory proxyClaimData,
        ) = this._encodePayload(payload);

        // check gauge data
        assertGt(gaugeBias, 0);

        // check user data
        assertEq(userClaimData.user, USER);
        assertGt(userClaimData.lastVote, 0);
        assertGt(userClaimData.lastVote, getCurrentPeriod());
        assertGt(userClaimData.userVoteSlope, 0);
        assertEq(userClaimData.userVotePower, 1000);
        assertGt(userClaimData.userVoteEnd, getCurrentPeriod());

        // check proxy data (expired)
        assertEq(proxyClaimData.user, address(0));
        assertEq(proxyClaimData.lastVote, 0);
        assertEq(proxyClaimData.userVoteSlope, 0);
        assertEq(proxyClaimData.userVotePower, 0);
        assertEq(proxyClaimData.userVoteEnd, 0);

        (bool success,) = address(platform).call(payload);
        assertTrue(success);
    }

    function testSendClaimStateWithProxy() external {
        address[] memory blacklist;

        vm.recordLogs();

        sender.claimOnDstChain(0, USER_2, GAUGE_2, GAUGE_CHAIN_ID, DST_CHAIN_ID, blacklist);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        (,, bytes memory payload) = abi.decode(entries[1].data, (string, string, bytes));

        (
            uint256 gaugeBias,
            IPlatformNoProof.ClaimData memory userClaimData,
            IPlatformNoProof.ClaimData memory proxyClaimData,
        ) = this._encodePayload(payload);

        // check gauge bias
        assertGt(gaugeBias, 0);

        // check user data
        assertEq(userClaimData.user, USER_2);
        assertGt(userClaimData.lastVote, 0);
        assertGt(userClaimData.lastVote, getCurrentPeriod());
        assertGt(userClaimData.userVoteSlope, 0);
        assertEq(userClaimData.userVotePower, 10000);
        assertGt(userClaimData.userVoteEnd, getCurrentPeriod());

        // check proxy data
        assertEq(proxyClaimData.user, USER_2_PROXY);
        assertGt(proxyClaimData.lastVote, 0);
        assertGt(proxyClaimData.lastVote, getCurrentPeriod());
        assertGt(proxyClaimData.userVoteSlope, 0);
        assertEq(proxyClaimData.userVotePower, 10000);
        assertGt(proxyClaimData.userVoteEnd, getCurrentPeriod());

        assertEq(userClaimData.lastVote, proxyClaimData.lastVote);

        (bool success,) = address(platform).call(payload);
        assertTrue(success);
    }

    function _encodePayload(bytes calldata _payload)
        public
        pure
        returns (
            uint256 gaugeBias,
            IPlatformNoProof.ClaimData memory userClaimData,
            IPlatformNoProof.ClaimData memory proxyClaimData,
            IPlatformNoProof.ClaimData[] memory blacklistClaimData
        )
    {
        // without proxy
        if (_payload.length == 356) {
            (,,, gaugeBias, userClaimData, blacklistClaimData) = abi.decode(
                _payload[4:],
                (uint256, address, uint256, uint256, IPlatformNoProof.ClaimData, IPlatformNoProof.ClaimData[])
            );
        } else {
            // with proxy
            (,,, gaugeBias, userClaimData, proxyClaimData, blacklistClaimData) = abi.decode(
                _payload[4:],
                (
                    uint256,
                    address,
                    uint256,
                    uint256,
                    IPlatformNoProof.ClaimData,
                    IPlatformNoProof.ClaimData,
                    IPlatformNoProof.ClaimData[]
                )
            );
        }
    }

    function getCurrentPeriod() public view returns (uint256) {
        return (block.timestamp / 1 weeks) * 1 weeks;
    }
}