// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {StateSender} from "src/StateSender.sol";
import {IGaugeVoting} from "src/interfaces/IGaugeVoting.sol";
import {IVotingEscrow} from "src/interfaces/IVotingEscrow.sol";
import {IAxelarGateway} from "src/interfaces/IAxelarGateway.sol";
import {IAxelarGasReceiverProxy} from "src/interfaces/IAxelarGasReceiverProxy.sol";
import {IPlatformNoProof} from "src/interfaces/IPlatformNoProof.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @title BnbGaugeVotingStateSender
/// @notice Sends weekly period block + block hash to a set of destination chains through Axelar
/// @dev This contract uses Axelar network for cross-chain communication
contract BnbGaugeVotingStateSender is StateSender {
    using LibString for address;

    struct Vm {
        address claimer;
        string chain;
    }

    mapping(uint256 => Vm) public vms; // dst chain id -> vm

    IGaugeVoting public constant GAUGE_VOTING = IGaugeVoting(0xf81953dC234cdEf1D6D0d3ef61b232C6bCbF9aeF);
    IVotingEscrow public constant VE_CAKE = IVotingEscrow(0x5692DB8177a81A6c6afc8084C2976C9933EC1bAB);

    constructor(address _governance, uint256 _sendBlockHashMinValue, uint256 _setRecipientMinValue)
        StateSender(
            _governance,
            0x304acf330bbE08d1e512eefaa92F6a57871fD895,
            0x2d5d7d31F671F86C782533cc367F14109a082712,
            _sendBlockHashMinValue,
            _setRecipientMinValue
        )
    {}

    function claimOnDstChain(
        uint256 _bountyId,
        address _user,
        address _gauge,
        uint256 _gaugeChainId,
        uint256 _dstChainId
    ) external payable {
        bytes32 gaugeHash = keccak256(abi.encodePacked(_gauge, _gaugeChainId));

        // check if the user own a proxy
        (,, address proxy,,,,,) = VE_CAKE.getUserInfo(_user);

        bytes memory payload;

        IGaugeVoting.Point memory points = GAUGE_VOTING.gaugePointsWeight(gaugeHash, getCurrentPeriod());

        IGaugeVoting.VotedSlope memory userSlope;
        IGaugeVoting.VotedSlope memory proxySlope;

        IPlatformNoProof.ClaimData memory userClaimData;
        IPlatformNoProof.ClaimData memory proxyClaimData;

        // if the user locked CAKE and he has not a proxy
        if (VE_CAKE.balanceOf(_user) != 0 && proxy == address(0)) {
            userSlope = GAUGE_VOTING.voteUserSlopes(_user, gaugeHash);

            userClaimData = IPlatformNoProof.ClaimData(
                _user,
                GAUGE_VOTING.lastUserVote(_user, gaugeHash),
                points.bias,
                points.slope,
                userSlope.slope,
                userSlope.power,
                userSlope.end
            );

            payload = abi.encodeWithSignature(
                "claim(uint256, address, (address, uint256, uint256, uint256, uint256, uint256, uint256))",
                _bountyId,
                _user,
                userClaimData
            );
        }

        // if the user did not lock any CAKE but he has a proxy
        if (VE_CAKE.balanceOf(_user) == 0 && proxy != address(0)) {
            proxySlope = GAUGE_VOTING.voteUserSlopes(proxy, gaugeHash);

            userClaimData = IPlatformNoProof.ClaimData(
                proxy,
                GAUGE_VOTING.lastUserVote(proxy, gaugeHash),
                points.bias,
                points.slope,
                proxySlope.slope,
                proxySlope.power,
                proxySlope.end
            );

            payload = abi.encodeWithSignature(
                "claim(uint256, address, (address, uint256, uint256, uint256, uint256, uint256, uint256))",
                _bountyId,
                _user,
                userClaimData
            );
        }

        // if the user locked CAKE and has a proxy
        if (VE_CAKE.balanceOf(_user) != 0 && proxy != address(0)) {
            userSlope = GAUGE_VOTING.voteUserSlopes(_user, gaugeHash);
            proxySlope = GAUGE_VOTING.voteUserSlopes(proxy, gaugeHash);

            userClaimData = IPlatformNoProof.ClaimData(
                _user,
                GAUGE_VOTING.lastUserVote(_user, gaugeHash),
                points.bias,
                points.slope,
                userSlope.slope,
                userSlope.power,
                userSlope.end
            );
            proxyClaimData = IPlatformNoProof.ClaimData(
                proxy,
                GAUGE_VOTING.lastUserVote(proxy, gaugeHash),
                points.bias,
                points.slope,
                proxySlope.slope,
                proxySlope.power,
                proxySlope.end
            );

            payload = abi.encodeWithSignature(
                "claimWithProxy(uint256, address, (address, uint256, uint256, uint256, uint256, uint256, uint256), (address, uint256, uint256, uint256, uint256, uint256, uint256))",
                _bountyId,
                _user,
                userClaimData,
                proxyClaimData
            );
        }

        if (payload.length > 0) {
            string memory destinationContractHex = vms[_dstChainId].claimer.toHexStringChecksumed();

            IAxelarGasReceiverProxy(axelarGasReceiver).payNativeGasForContractCall{value: msg.value}(
                address(this), vms[_dstChainId].chain, destinationContractHex, payload, msg.sender
            );

            IAxelarGateway(axelarGateway).callContract(vms[_dstChainId].chain, destinationContractHex, payload);
        }
    }

    function addVm(address _claimer, string memory _dstChain, uint256 _dstChainId) external onlyGovernance {
        vms[_dstChainId] = Vm(_claimer, _dstChain);
    }
}
