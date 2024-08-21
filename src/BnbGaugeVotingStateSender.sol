// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import {IGaugeVoting} from "src/interfaces/IGaugeVoting.sol";
import {IVotingEscrow} from "src/interfaces/IVotingEscrow.sol";
import {IAxelarGateway} from "src/interfaces/IAxelarGateway.sol";
import {IAxelarGasReceiverProxy} from "src/interfaces/IAxelarGasReceiverProxy.sol";
import {IPlatform} from "src/interfaces/IPlatform.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @title BnbGaugeVotingStateSender
/// @notice Sends users's gauge voting datas to a supported dst chains through Axelar
/// @dev This contract uses Axelar network for cross-chain communication
contract BnbGaugeVotingStateSender {
    using LibString for address;

    struct Vm {
        address claimer;
        string chain;
    }

    mapping(uint256 => Vm) public vms; // dst chain id -> vm

    address public constant AXELAR_GATEWAY = 0x304acf330bbE08d1e512eefaa92F6a57871fD895;
    address public constant AXELAR_GAS_RECEIVER = 0x2d5d7d31F671F86C782533cc367F14109a082712;
    IGaugeVoting public constant GAUGE_VOTING = IGaugeVoting(0xf81953dC234cdEf1D6D0d3ef61b232C6bCbF9aeF);
    IVotingEscrow public constant VE_CAKE = IVotingEscrow(0x5692DB8177a81A6c6afc8084C2976C9933EC1bAB);

    address public governance;
    address public futureGovernance;

    uint256 public claimMinValue;
    uint256 public setRecipientMinValue;

    error GovernanceOnly();
    error InsufficientValue();
    error UserWithoutSlope();

    event GovernanceChanged(address indexed newGovernance);
    event RecipientSet(address indexed sender, address indexed recipient, string indexed chain);
    event RecipientMinValueSet(uint256 newValue);
    event SetClaimerMinValueSet(uint256 newValue);
    event VmSet(uint256 indexed dstChainId, address indexed claimer, string dstChain);

    modifier onlyGovernance() {
        if (msg.sender != governance) revert GovernanceOnly();
        _;
    }

    constructor(address _governance, uint256 _claimMinValue, uint256 _setRecipientMinValue) {
        governance = _governance;
        claimMinValue = _claimMinValue;
        setRecipientMinValue = _setRecipientMinValue;
    }

    /// @notice Claim bounty reward
    /// @param _bountyId Bounty ID.
    /// @param _user Address of the voter.
    /// @param _gauge Address of the gauge voted for.
    /// @param _gaugeChainId Gauge chain id.
    /// @param _dstChainId Destination chain id.
    /// @param _blacklist Blacklist addresses.
    function claimOnDstChain(
        uint256 _bountyId,
        address _user,
        address _gauge,
        uint256 _gaugeChainId,
        uint256 _dstChainId,
        address[] calldata _blacklist
    ) external payable {
        // check if msg.value is enough
        if (msg.value < claimMinValue) revert InsufficientValue();

        // calculate total slope
        IPlatform.ClaimData[] memory claimData = new IPlatform.ClaimData[](1 + _blacklist.length);

        bytes32 gaugeHash = keccak256(abi.encodePacked(_gauge, _gaugeChainId));

        // get user claim data (locker and/or proxy)
        claimData[0] = _getClaimData(_user, gaugeHash);

        if (claimData[0].userVoteSlope == 0) revert UserWithoutSlope();

        // fill blacklist counting the user's proxy too
        if (_blacklist.length > 0) {
            for (uint256 i; i < _blacklist.length;) {
                claimData[i + 1] = _getClaimData(_blacklist[i], gaugeHash);
                unchecked {
                    ++i;
                }
            }
        }

        // calculate payload to bridge
        bytes memory payload = abi.encodeWithSelector(
            IPlatform.claim.selector, _bountyId, _gauge, block.timestamp, _getGaugeBias(gaugeHash), claimData
        );

        // create payload to send to dst chain
        address destinationContract = vms[_dstChainId].claimer;

        if (destinationContract != address(0)) {
            string memory destinationContractHex = destinationContract.toHexStringChecksumed();

            IAxelarGasReceiverProxy(AXELAR_GAS_RECEIVER).payNativeGasForContractCall{value: msg.value}(
                address(this), vms[_dstChainId].chain, destinationContractHex, payload, msg.sender
            );

            IAxelarGateway(AXELAR_GATEWAY).callContract(vms[_dstChainId].chain, destinationContractHex, payload);
        }
    }

    /// @notice Get claim data
    /// @param _user Address of the voter.
    /// @param _gaugeHash Gauge hash.
    function _getClaimData(address _user, bytes32 _gaugeHash) internal returns (IPlatform.ClaimData memory claimData) {
        claimData.user = _user;

        IGaugeVoting.VotedSlope memory userSlope = GAUGE_VOTING.voteUserSlopes(_user, _gaugeHash);

        // check if the locker is not expired
        if (userSlope.end > getCurrentPeriod()) {
            claimData.userVoteSlope += userSlope.slope;
            claimData.lastVote = GAUGE_VOTING.lastUserVote(_user, _gaugeHash);
            claimData.userVoteEnd = userSlope.end;
        }

        // check if the user own a proxy
        (,, address proxy,, uint256 proxyEndTime,,,) = VE_CAKE.getUserInfo(_user);

        // check if the proxy is not expired
        if (proxy != address(0) && proxyEndTime > getCurrentPeriod()) {
            userSlope = GAUGE_VOTING.voteUserSlopes(proxy, _gaugeHash);
            claimData.userVoteSlope += userSlope.slope;
            if (claimData.lastVote == 0) {
                claimData.lastVote = GAUGE_VOTING.lastUserVote(proxy, _gaugeHash);
            }
            if (claimData.userVoteEnd == 0 || claimData.userVoteEnd > userSlope.end) {
                claimData.userVoteEnd = userSlope.end;
            }
        }
    }

    /// @notice Get gauge bias for the current period
    /// @param _gaugeHash Gauge hash
    function _getGaugeBias(bytes32 _gaugeHash) internal returns (uint256 gaugeBias) {
        gaugeBias = GAUGE_VOTING.gaugePointsWeight(_gaugeHash, getCurrentPeriod()).bias;
    }

    /// @notice Sets the recipient for an address on oracle.
    /// @param _dstChainId Name of the chain.
    /// @param _recipient Address to set as the recipient.
    function setRecipient(uint256 _dstChainId, address _recipient) external payable {
        if (msg.value < setRecipientMinValue) revert InsufficientValue();

        address destinationContract = vms[_dstChainId].claimer;

        if (destinationContract != address(0)) {
            bytes memory payload = abi.encodeWithSignature("setRecipient(address,address)", msg.sender, _recipient);

            string memory dstChain = vms[_dstChainId].chain;
            string memory destinationContractHex = destinationContract.toHexStringChecksumed();

            IAxelarGasReceiverProxy(AXELAR_GAS_RECEIVER).payNativeGasForContractCall{value: msg.value}(
                address(this), dstChain, destinationContractHex, payload, msg.sender
            );

            IAxelarGateway(AXELAR_GATEWAY).callContract(dstChain, destinationContractHex, payload);

            emit RecipientSet(msg.sender, _recipient, dstChain);
        }
    }

    /// @notice Set a xchain vote market info.
    /// @param _claimer Address of the destination claimer contract.
    /// @param _dstChain Name of the destination chain.
    /// @param _dstChainId Destination chain ID.
    function setVm(address _claimer, string memory _dstChain, uint256 _dstChainId) external onlyGovernance {
        vms[_dstChainId] = Vm(_claimer, _dstChain);

        emit VmSet(_dstChainId, _claimer, _dstChain);
    }

    /// @notice Set the min gas value to set the recipient
    /// @param _newValue min value
    function setMinValueForSetRecipient(uint256 _newValue) external onlyGovernance {
        emit RecipientMinValueSet(setRecipientMinValue = _newValue);
    }

    /// @notice Set the min gas value to claim a bounty
    /// @param _newValue min value
    function setClaimMinValue(uint256 _newValue) external onlyGovernance {
        emit SetClaimerMinValueSet(claimMinValue = _newValue);
    }

    /// @notice Transfer the governance to a new address.
    /// @param _governance Address of the new governance.
    function transferGovernance(address _governance) external onlyGovernance {
        futureGovernance = _governance;
    }

    /// @notice Accept the governance transfer.
    function acceptGovernance() external {
        if (msg.sender != futureGovernance) revert GovernanceOnly();

        governance = msg.sender;

        /// Reset the future governance.
        futureGovernance = address(0);

        emit GovernanceChanged(msg.sender);
    }

    /// @notice Calculates the current period based on weekly intervals
    /// @return uint256 The start of the current weekly period
    function getCurrentPeriod() public view returns (uint256) {
        return (block.timestamp / 1 weeks) * 1 weeks;
    }
}
