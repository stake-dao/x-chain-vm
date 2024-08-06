// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.20;

import "test/utils/Utils.sol";
import {IAxelarGateway} from "../src/interfaces/IAxelarGateway.sol";
import {IAxelarGasReceiverProxy} from "../src/interfaces/IAxelarGasReceiverProxy.sol";
import {EthereumStateSender} from "../src/EthereumStateSender.sol";
import {MockAxelarGateway} from "./mocks/MockAxelarGateway.sol";
import {MockAxelarGasReceiver} from "./mocks/MockAxelarGasReceiver.sol";
import {BnbGaugeVotingStateSender} from "src/BnbGaugeVotingStateSender.sol";

contract BnbGaugeVotingStateSenderTest is Utils {
    BnbGaugeVotingStateSender internal sender;

    address internal constant USER = 0xb3C97eEA5900E8A620434d7E3A954dA512df7593;
    address internal constant GAUGE = 0x6425bC30D0751aF5181fC74a50e760b0e4a19811;
    uint256 internal constant GAUGE_CHAIN_ID = 56;
    uint256 internal constant DST_CHAIN_ID = 42161;

    address internal claimer = address(0xAAAA);

    function setUp() public {
        uint256 forkId = vm.createFork("bsc");
        vm.selectFork(forkId);

        sender = new BnbGaugeVotingStateSender(address(this), 0.003 ether, 0.001 ether);

        sender.addVm(claimer, "arbitrum", DST_CHAIN_ID);
    }

    function testSendClaimState() external {
        sender.claimOnDstChain(0, USER, GAUGE, GAUGE_CHAIN_ID, DST_CHAIN_ID);
    }
}
