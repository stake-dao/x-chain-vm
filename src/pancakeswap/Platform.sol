// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;
/*
▄▄▄█████▓ ██░ ██ ▓█████     ██░ ██ ▓█████  ██▀███  ▓█████▄ 
▓  ██▒ ▓▒▓██░ ██▒▓█   ▀    ▓██░ ██▒▓█   ▀ ▓██ ▒ ██▒▒██▀ ██▌
▒ ▓██░ ▒░▒██▀▀██░▒███      ▒██▀▀██░▒███   ▓██ ░▄█ ▒░██   █▌
░ ▓██▓ ░ ░▓█ ░██ ▒▓█  ▄    ░▓█ ░██ ▒▓█  ▄ ▒██▀▀█▄  ░▓█▄   ▌
  ▒██▒ ░ ░▓█▒░██▓░▒████▒   ░▓█▒░██▓░▒████▒░██▓ ▒██▒░▒████▓ 
  ▒ ░░    ▒ ░░▒░▒░░ ▒░ ░    ▒ ░░▒░▒░░ ▒░ ░░ ▒▓ ░▒▓░ ▒▒▓  ▒ 
    ░     ▒ ░▒░ ░ ░ ░  ░    ▒ ░▒░ ░ ░ ░  ░  ░▒ ░ ▒░ ░ ▒  ▒ 
  ░       ░  ░░ ░   ░       ░  ░░ ░   ░     ░░   ░  ░ ░  ░ 
          ░  ░  ░   ░  ░    ░  ░  ░   ░  ░   ░        ░    
                                                    ░      
              .,;>>%%%%%>>;,.
           .>%%%%%%%%%%%%%%%%%%%%>,.
         .>%%%%%%%%%%%%%%%%%%>>,%%%%%%;,.
       .>>>>%%%%%%%%%%%%%>>,%%%%%%%%%%%%,>>%%,.
     .>>%>>>>%%%%%%%%%>>,%%%%%%%%%%%%%%%%%,>>%%%%%,.
   .>>%%%%%>>%%%%>>,%%>>%%%%%%%%%%%%%%%%%%%%,>>%%%%%%%,
  .>>%%%%%%%%%%>>,%%%%%%>>%%%%%%%%%%%%%%%%%%,>>%%%%%%%%%%.
  .>>%%%%%%%%%%>>,>>>>%%%%%%%%%%'..`%%%%%%%%,;>>%%%%%%%%%>%%.
.>>%%%>>>%%%%%>,%%%%%%%%%%%%%%.%%%,`%%%%%%,;>>%%%%%%%%>>>%%%%.
>>%%>%>>>%>%%%>,%%%%%>>%%%%%%%%%%%%%`%%%%%%,>%%%%%%%>>>>%%%%%%%.
>>%>>>%%>>>%%%%>,%>>>%%%%%%%%%%%%%%%%`%%%%%%%%%%%%%%%%%%%%%%%%%%.
>>%%%%%%%%%%%%%%,>%%%%%%%%%%%%%%%%%%%'%%%,>>%%%%%%%%%%%%%%%%%%%%%.
>>%%%%%%%%%%%%%%%,>%%%>>>%%%%%%%%%%%%%%%,>>%%%%%%%%>>>>%%%%%%%%%%%.
>>%%%%%%%%;%;%;%%;,%>>>>%%%%%%%%%%%%%%%,>>>%%%%%%>>;";>>%%%%%%%%%%%%.
`>%%%%%%%%%;%;;;%;%,>%%%%%%%%%>>%%%%%%%%,>>>%%%%%%%%%%%%%%%%%%%%%%%%%%.
 >>%%%%%%%%%,;;;;;%%>,%%%%%%%%>>>>%%%%%%%%,>>%%%%%%%%%%%%%%%%%%%%%%%%%%%.
 `>>%%%%%%%%%,%;;;;%%%>,%%%%%%%%>>>>%%%%%%%%,>%%%%%%'%%%%%%%%%%%%%%%%%%%>>.
  `>>%%%%%%%%%%>,;;%%%%%>>,%%%%%%%%>>%%%%%%';;;>%%%%%,`%%%%%%%%%%%%%%%>>%%>.
   >>>%%%%%%%%%%>> %%%%%%%%>>,%%%%>>>%%%%%';;;;;;>>,%%%,`%     `;>%%%%%%>>%%
   `>>%%%%%%%%%%>> %%%%%%%%%>>>>>>>>;;;;'.;;;;;>>%%'  `%%'          ;>%%%%%>
    >>%%%%%%%%%>>; %%%%%%%%>>;;;;;;''    ;;;;;>>%%%                   ;>%%%%
    `>>%%%%%%%>>>, %%%%%%%%%>>;;'        ;;;;>>%%%'                    ;>%%%
     >>%%%%%%>>>':.%%%%%%%%%%>>;        .;;;>>%%%%                    ;>%%%'
     `>>%%%%%>>> ::`%%%%%%%%%%>>;.      ;;;>>%%%%'                   ;>%%%'
      `>>%%%%>>> `:::`%%%%%%%%%%>;.     ;;>>%%%%%                   ;>%%'
       `>>%%%%>>, `::::`%%%%%%%%%%>,   .;>>%%%%%'                   ;>%'
        `>>%%%%>>, `:::::`%%%%%%%%%>>. ;;>%%%%%%                    ;>%,
         `>>%%%%>>, :::::::`>>>%%%%>>> ;;>%%%%%'                     ;>%,
          `>>%%%%>>,::::::,>>>>>>>>>>' ;;>%%%%%                       ;%%,
            >>%%%%>>,:::,%%>>>>>>>>'   ;>%%%%%.                        ;%%
             >>%%%%>>``%%%%%>>>>>'     `>%%%%%%.
             >>%%%%>> `@@a%%%%%%'     .%%%%%%%%%.
             `a@@a%@'    `%a@@'       `a@@a%a@@a
 */

import {Owned} from "solmate/auth/Owned.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IGaugeVotingOracle} from "src/interfaces/IGaugeVotingOracle.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

/// @title PancakeSwap Platform
/// @author Stake DAO
/// @notice XChain VoteMarket for PancakeSwap gauges. Takes into account the 2 weeks voting Epoch, so claimable period active on EVEN week Thursday.
/// @dev Forked from Platform contract
contract Platform is Owned, ReentrancyGuard {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    ////////////////////////////////////////////////////////////////
    /// --- EMERGENCY SHUTDOWN
    ///////////////////////////////////////////////////////////////

    /// @notice Emergency shutdown flag
    bool public isKilled;

    ////////////////////////////////////////////////////////////////
    /// --- STRUCTS
    ///////////////////////////////////////////////////////////////

    /// @notice Bounty struct requirements.
    struct Bounty {
        // Address of the target gauge.
        address gauge;
        // Chain ID of the target gauge.
        uint256 chainId;
        // Manager.
        address manager;
        // Address of the ERC20 used for rewards.
        address rewardToken;
        // Number of epochs.
        uint8 numberOfEpochs;
        // Timestamp where the bounty become unclaimable.
        uint256 endTimestamp;
        // Max Price per vote.
        uint256 maxRewardPerVote;
        // Total Reward Added.
        uint256 totalRewardAmount;
        // Blacklisted addresses.
        address[] blacklist;
    }

    struct Upgrade {
        // Number of epochs after increase.
        uint8 numberOfEpochs;
        // Total reward amount after increase.
        uint256 totalRewardAmount;
        // New max reward per vote after increase.
        uint256 maxRewardPerVote;
        // New end timestamp after increase.
        uint256 endTimestamp;
    }

    /// @notice Period struct.
    struct Period {
        // Period id.
        // Eg: 0 is the first period, 1 is the second period, etc.
        uint8 id;
        // Timestamp of the period start.
        uint256 timestamp;
        // Reward amount distributed during the period.
        uint256 rewardPerPeriod;
    }

    /// @notice Proof struct.
    struct ProofData {
        // Address of user.
        address user;
        // RLP Encoded header.
        bytes headerRlp;
        // RLP Encoded proof.
        bytes userProofRlp;
        // RLP Encoded blacklisted addresses proof.
        bytes[] blackListedProofsRlp;
    }

    ////////////////////////////////////////////////////////////////
    /// --- CONSTANTS & IMMUTABLES
    ///////////////////////////////////////////////////////////////

    /// @notice Minimum duration a Bounty.
    uint8 public constant MINIMUM_EPOCH = 1;

    /// @notice Week in seconds.
    uint256 private constant _WEEK = 1 weeks;
    uint256 private constant _TWOWEEKS = 2 weeks;

    /// @notice Base unit for fixed point compute.
    uint256 private constant _BASE_UNIT = 1e18;

    /// @notice Default fee.
    uint256 internal constant _DEFAULT_FEE = 2e16; // 2%

    /// @notice Gauge Controller.
    IGaugeVotingOracle public gaugeController;

    ////////////////////////////////////////////////////////////////
    /// --- STORAGE VARS
    ///////////////////////////////////////////////////////////////

    /// @notice Fee.
    uint256 public fee;

    /// @notice Bounty ID Counter.
    uint256 public nextID;

    /// @notice Fee collector.
    address public feeCollector;

    /// @notice ID => Bounty.
    mapping(uint256 => Bounty) public bounties;

    /// @notice Whitelisted Address(Liquid Wrappers) to prevent claiming on their behalf if no recipient is set.
    mapping(address => bool) public whitelisted;

    /// @notice Recipient per address.
    mapping(address => address) public recipient;

    /// @notice Fee accrued per rewardToken.
    mapping(address => uint256) public feeAccrued;

    /// @notice BountyId => isUpgradeable. If true, the bounty can be upgraded.
    mapping(uint256 => bool) public isUpgradeable;

    /// @notice ID => Period running.
    mapping(uint256 => Period) public activePeriod;

    /// @notice ID => Amount Claimed per Bounty.
    mapping(uint256 => uint256) public amountClaimed;

    /// @notice ID => Amount of reward per vote distributed.
    mapping(uint256 => uint256) public rewardPerVote;

    /// @notice ID => Bounty In Queue to be upgraded.
    mapping(uint256 => Upgrade) public upgradeBountyQueue;

    /// @notice Blacklisted addresses per bounty that aren't counted for rewards arithmetics.
    mapping(uint256 => mapping(address => bool)) public isBlacklisted;

    /// @notice Last time a user claimed
    mapping(address => mapping(uint256 => uint256)) public lastUserClaim;

    /// @notice (Gauge, SnapshotBlock) => Adjusted Bias.
    mapping(address => mapping(uint256 => uint256)) public gaugeAdjustedBias;

    ////////////////////////////////////////////////////////////////
    /// --- MODIFIERS
    ///////////////////////////////////////////////////////////////

    modifier notKilled() {
        if (isKilled) revert KILLED();
        _;
    }

    modifier onlyManager(uint256 _id) {
        if (msg.sender != bounties[_id].manager) revert AUTH_MANAGER_ONLY();
        _;
    }

    ////////////////////////////////////////////////////////////////
    /// --- EVENTS
    ///////////////////////////////////////////////////////////////

    /// @notice Emitted when a new bounty is created.
    /// @param id Bounty ID.
    /// @param gauge Gauge address.
    /// @param manager Manager address.
    /// @param rewardToken Reward token address.
    /// @param numberOfPeriods Number of periods.
    /// @param maxRewardPerVote Max reward per vote.
    /// @param rewardPerPeriod Reward per period.
    /// @param totalRewardAmount Total reward amount.
    /// @param isUpgradeable If true, the bounty can be upgraded.
    event BountyCreated(
        uint256 indexed id,
        address indexed gauge,
        uint256 chainId,
        address manager,
        address rewardToken,
        uint8 numberOfPeriods,
        uint256 maxRewardPerVote,
        uint256 rewardPerPeriod,
        uint256 totalRewardAmount,
        bool isUpgradeable
    );

    /// @notice Emitted when a bounty is closed.
    /// @param id Bounty ID.
    /// @param remainingReward Remaining reward.
    event BountyClosed(uint256 id, uint256 remainingReward);

    /// @notice Emitted when a bounty period is rolled over.
    /// @param id Bounty ID.
    /// @param periodId Period ID.
    /// @param timestamp Period timestamp.
    /// @param rewardPerPeriod Reward per period.
    event PeriodRolledOver(uint256 id, uint256 periodId, uint256 timestamp, uint256 rewardPerPeriod);

    /// @notice Emitted on claim.
    /// @param user User address.
    /// @param rewardToken Reward token address.
    /// @param bountyId Bounty ID.
    /// @param amount Amount claimed.
    /// @param protocolFees Protocol fees.
    /// @param period Period timestamp.
    event Claimed(
        address indexed user,
        address rewardToken,
        uint256 indexed bountyId,
        uint256 amount,
        uint256 protocolFees,
        uint256 period
    );

    /// @notice Emitted when a bounty is queued to upgrade.
    /// @param id Bounty ID.
    /// @param numberOfPeriods Number of periods.
    /// @param totalRewardAmount Total reward amount.
    /// @param maxRewardPerVote Max reward per vote.
    event BountyDurationIncreaseQueued(
        uint256 id, uint8 numberOfPeriods, uint256 totalRewardAmount, uint256 maxRewardPerVote
    );

    /// @notice Emitted when a bounty is upgraded.
    /// @param id Bounty ID.
    /// @param numberOfPeriods Number of periods.
    /// @param totalRewardAmount Total reward amount.
    /// @param maxRewardPerVote Max reward per vote.
    event BountyDurationIncrease(
        uint256 id, uint8 numberOfPeriods, uint256 totalRewardAmount, uint256 maxRewardPerVote
    );

    /// @notice Emitted when a bounty manager is updated.
    /// @param id Bounty ID.
    /// @param manager Manager address.
    event ManagerUpdated(uint256 id, address indexed manager);

    /// @notice Emitted when a recipient is set for an address.
    /// @param sender Sender address.
    /// @param recipient Recipient address.
    event RecipientSet(address indexed sender, address indexed recipient);

    /// @notice Emitted when fee is updated.
    /// @param fee Fee.
    event FeeUpdated(uint256 fee);

    /// @notice Emitted when fee collector is updated.
    /// @param feeCollector Fee collector.
    event FeeCollectorUpdated(address feeCollector);

    /// @notice Emitted when gauge controller (oracle) is updated.
    /// @param gaugeController Gauge controller.
    event GaugeControllerUpdated(address gaugeController);

    /// @notice Emitted when fees are collected.
    /// @param rewardToken Reward token address.
    /// @param amount Amount collected.
    event FeesCollected(address indexed rewardToken, uint256 amount);

    ////////////////////////////////////////////////////////////////
    /// --- ERRORS
    ///////////////////////////////////////////////////////////////

    error KILLED();
    error WRONG_INPUT();
    error ZERO_ADDRESS();
    error INVALID_TOKEN();
    error ALREADY_CLOSED();
    error NO_PERIODS_LEFT();
    error USER_NOT_UPDATED();
    error NOT_UPGRADEABLE();
    error AUTH_MANAGER_ONLY();
    error INVALID_NUMBER_OF_EPOCHS();
    error NO_RECEIVER_SET_FOR_WHITELISTED();
    error WRONG_PROXY_PROOF();

    ////////////////////////////////////////////////////////////////
    /// --- CONSTRUCTOR
    ///////////////////////////////////////////////////////////////

    /// @notice Create Bounty platform.
    /// @param _gaugeController Address of the gauge controller.
    constructor(address _gaugeController, address _feeCollector, address _owner) Owned(_owner) {
        fee = _DEFAULT_FEE;
        feeCollector = _feeCollector;
        gaugeController = IGaugeVotingOracle(_gaugeController);
    }

    ////////////////////////////////////////////////////////////////
    /// --- BOUNTY CREATION LOGIC
    ///////////////////////////////////////////////////////////////

    /// @notice Create a new bounty.
    /// @param gauge Address of the target gauge.
    /// @param rewardToken Address of the ERC20 used or rewards.
    /// @param numberOfEpochs Number of epochs.
    /// @param maxRewardPerVote Target Bias for the Gauge.
    /// @param totalRewardAmount Total Reward Added.
    /// @param blacklist Array of addresses to blacklist.
    /// @return newBountyId of the bounty created.
    function createBounty(
        address gauge,
        uint256 chainId,
        address manager,
        address rewardToken,
        uint8 numberOfEpochs,
        uint256 maxRewardPerVote,
        uint256 totalRewardAmount,
        address[] calldata blacklist,
        bool upgradeable
    ) external nonReentrant notKilled returns (uint256 newBountyId) {
        if (numberOfEpochs < MINIMUM_EPOCH) revert INVALID_NUMBER_OF_EPOCHS();
        if (totalRewardAmount == 0 || maxRewardPerVote == 0) revert WRONG_INPUT();
        if (rewardToken == address(0) || manager == address(0)) revert ZERO_ADDRESS();

        uint256 size;
        assembly {
            size := extcodesize(rewardToken)
        }
        if (size == 0) revert INVALID_TOKEN();

        // Transfer the rewards to the contracts.
        SafeTransferLib.safeTransferFrom(rewardToken, msg.sender, address(this), totalRewardAmount);

        unchecked {
            // Get the ID for that new Bounty and increment the nextID counter.
            newBountyId = nextID;

            ++nextID;
        }

        uint256 rewardPerPeriod = totalRewardAmount.mulDiv(1, numberOfEpochs);
        //uint256 currentEpoch = getCurrentEpoch();

        bounties[newBountyId] = Bounty({
            gauge: gauge,
            chainId: chainId,
            manager: manager,
            rewardToken: rewardToken,
            numberOfEpochs: numberOfEpochs,
            endTimestamp: getCurrentEpoch() + ((numberOfEpochs + 1) * _TWOWEEKS),
            maxRewardPerVote: maxRewardPerVote,
            totalRewardAmount: totalRewardAmount,
            blacklist: blacklist
        });

        emit BountyCreated(
            newBountyId,
            gauge,
            chainId,
            manager,
            rewardToken,
            numberOfEpochs,
            maxRewardPerVote,
            rewardPerPeriod,
            totalRewardAmount,
            upgradeable
        );

        // Set Upgradeable status.
        isUpgradeable[newBountyId] = upgradeable;
        // Period is two weeks rounded down to the first. Active claimable period should start on the week just after
        activePeriod[newBountyId] = Period(0, getCurrentEpoch() + _TWOWEEKS, rewardPerPeriod);

        // Add the addresses to the blacklist.
        uint256 length = blacklist.length;
        for (uint256 i = 0; i < length;) {
            // Retrieve if user has Cake Pool Proxy
            // (,, address cakePoolProxy,,,,,) = escrow.getUserInfo(blacklist[i]);

            // if (cakePoolProxy != address(0)) {
            //     isBlacklisted[newBountyId][cakePoolProxy] = true;
            // }

            isBlacklisted[newBountyId][blacklist[i]] = true;
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Claim rewards for a given bounty.
    /// @param bountyId ID of the bounty.
    /// @param proofUserVote User vote proof.
    /// @param proofProxyVote Proxy vote proof.
    /// @param proofProxyOwner Proxy ownership proof.
    /// @return Amount of rewards claimed.
    function claim(
        uint256 bountyId,
        ProofData memory proofUserVote,
        ProofData memory proofProxyVote,
        ProofData memory proofProxyOwner
    ) external returns (uint256) {
        return _claim(bountyId, proofUserVote, proofProxyVote, proofProxyOwner);
    }

    /// @notice Claim all rewards for multiple bounties.
    /// @param ids Array of bounty IDs to claim.
    /// @param proofsUserVote Array of user vote proof.
    /// @param proofsProxyVote Array of proxy vote proof.
    /// @param proofsProxyOwner Array of proxy ownership proof.
    function claimAll(
        uint256[] calldata ids,
        ProofData[] calldata proofsUserVote,
        ProofData[] calldata proofsProxyVote,
        ProofData[] calldata proofsProxyOwner
    ) external {
        uint256 length = ids.length;

        for (uint256 i = 0; i < length;) {
            uint256 id = ids[i];

            _claim(id, proofsUserVote[i], proofsProxyVote[i], proofsProxyOwner[i]);

            unchecked {
                ++i;
            }
        }
    }

    ////////////////////////////////////////////////////////////////
    /// --- INTERNAL LOGIC
    ///////////////////////////////////////////////////////////////

    /// @notice Claim rewards for a given bounty.
    /// @param bountyId ID of the bounty.
    /// @param proofUserVote User vote proof.
    /// @param proofProxyVote User's proxy vote proof.
    /// @param proofProxyOwner Proxy ownership proof.
    /// @return amount of rewards claimed.
    function _claim(
        uint256 bountyId,
        ProofData memory proofUserVote,
        ProofData memory proofProxyVote,
        ProofData memory proofProxyOwner
    ) internal notKilled returns (uint256 amount) {
        // Update if needed the current period.
        uint256 currentEpoch = _updateBountyPeriod(bountyId, proofUserVote);
        uint256 snapshotBlock = gaugeController.last_eth_block_number();

        if (currentEpoch != gaugeController.activePeriod()) return 0;

        Bounty storage bounty = bounties[bountyId];

        // Checking votes from user
        amount += _getClaimable(proofUserVote, snapshotBlock, bounty, bountyId, currentEpoch);

        // Checking the user's proxy ownership
        // claim for proxy
        if (proofProxyVote.user != address(0)) {
            address cakePoolProxy = gaugeController.veCakeProxy(proofUserVote.user);
            if (cakePoolProxy == address(0)) {
                (cakePoolProxy,,) = gaugeController.extractVeCakeProofState(
                    proofProxyOwner.user, proofProxyOwner.headerRlp, proofProxyOwner.userProofRlp
                );
            }
            if (cakePoolProxy != proofProxyVote.user) revert WRONG_PROXY_PROOF();
            // If there is a proxy (migrated cake), checking also votes for it
            amount += _getClaimable(proofProxyVote, snapshotBlock, bounty, bountyId, currentEpoch);
        }

        if (amount == 0) {
            return 0;
        }

        // Update the amount claimed.
        uint256 _amountClaimed = amountClaimed[bountyId];

        if (amount + _amountClaimed > bounty.totalRewardAmount) {
            amount = bounty.totalRewardAmount - _amountClaimed;
        }

        amountClaimed[bountyId] += amount;

        uint256 feeAmount;

        if (fee != 0) {
            feeAmount = amount.mulWad(fee);
            amount -= feeAmount;
            feeAccrued[bounty.rewardToken] += feeAmount;
        }

        address receiver = gaugeController.recipient(proofUserVote.user);
        if (whitelisted[proofUserVote.user] && receiver == address(0)) revert NO_RECEIVER_SET_FOR_WHITELISTED();
        receiver = receiver != address(0) ? receiver : proofUserVote.user;

        // Transfer reward to user.
        SafeTransferLib.safeTransfer(bounty.rewardToken, receiver, amount);
        emit Claimed(proofUserVote.user, bounty.rewardToken, bountyId, amount, feeAmount, currentEpoch);
    }

    /// @dev Internal function to avoid doing redundantly claim calculations (proxy + user)
    function _getClaimable(
        ProofData memory proofData,
        uint256 snapshotBlock,
        Bounty memory bounty,
        uint256 bountyId,
        uint256 currentEpoch
    ) internal returns (uint256 amount) {
        IGaugeVotingOracle.VotedSlope memory userSlope;
        uint256 lastVote;

        if (gaugeController.isUserUpdated(snapshotBlock, proofData.user, bounty.gauge)) {
            userSlope = gaugeController.voteUserSlope(snapshotBlock, proofData.user, bounty.gauge);
            lastVote = gaugeController.lastUserVote(snapshotBlock, proofData.user, bounty.gauge);
        } else {
            (, userSlope, lastVote,) = gaugeController.extractProofState(
                proofData.user, bounty.gauge, proofData.headerRlp, proofData.userProofRlp
            );
        }

        if (
            userSlope.slope == 0 || lastUserClaim[proofData.user][bountyId] >= currentEpoch
                || currentEpoch >= userSlope.end || currentEpoch <= lastVote || currentEpoch >= bounty.endTimestamp
                || currentEpoch != getCurrentEpoch() || amountClaimed[bountyId] == bounty.totalRewardAmount
        ) return 0;

        lastUserClaim[proofData.user][bountyId] = currentEpoch;

        // Voting Power = userSlope * dt
        // with dt = lock_end - period.
        uint256 _bias = _getAddrBias(userSlope.slope, userSlope.end, currentEpoch);
        // Compute the reward amount based on
        // Reward / Total Votes.
        amount = _bias.mulWad(rewardPerVote[bountyId]);
        // Compute the reward amount based on
        // the max price to pay.
        uint256 _amountWithMaxPrice = _bias.mulWad(bounty.maxRewardPerVote);
        // Distribute the _min between the amount based on votes, and price.
        amount = FixedPointMathLib.min(amount, _amountWithMaxPrice);
    }

    /// @notice Update the current period for a given bounty.
    /// @param bountyId Bounty ID.
    /// @return current/updated period.
    function _updateBountyPeriod(uint256 bountyId, ProofData memory proofData) internal returns (uint256) {
        Period storage _activePeriod = activePeriod[bountyId];

        uint256 currentEpoch = getCurrentEpoch();

        if (_activePeriod.id == 0 && currentEpoch == _activePeriod.timestamp && rewardPerVote[bountyId] == 0) {
            // Check if there is an upgrade in queue and update the bounty.
            _checkForUpgrade(bountyId);
            // Initialize reward per vote.
            // Only for the first period, and if not already initialized.
            _updateRewardPerToken(bountyId, currentEpoch, proofData);
        }

        // Increase Period after the active period (period on 2 weeks rounded down to the first, so week after)
        if (block.timestamp >= _activePeriod.timestamp + _TWOWEEKS) {
            // Check if there is an upgrade in queue and update the bounty.
            _checkForUpgrade(bountyId);

            // Roll to next period.
            _rollOverToNextPeriod(bountyId, currentEpoch, proofData);

            return currentEpoch;
        }

        return _activePeriod.timestamp;
    }

    /// @notice Checks for an upgrade and update the bounty.
    function _checkForUpgrade(uint256 bountyId) internal {
        Upgrade storage upgradedBounty = upgradeBountyQueue[bountyId];

        // Check if there is an upgrade in queue.
        if (upgradedBounty.totalRewardAmount != 0) {
            // Save new values.
            bounties[bountyId].endTimestamp = upgradedBounty.endTimestamp;
            bounties[bountyId].numberOfEpochs = upgradedBounty.numberOfEpochs;
            bounties[bountyId].maxRewardPerVote = upgradedBounty.maxRewardPerVote;
            bounties[bountyId].totalRewardAmount = upgradedBounty.totalRewardAmount;

            if (activePeriod[bountyId].id == 0) {
                activePeriod[bountyId].rewardPerPeriod =
                    upgradedBounty.totalRewardAmount.mulDiv(1, upgradedBounty.numberOfEpochs);
            }

            emit BountyDurationIncrease(
                bountyId,
                upgradedBounty.numberOfEpochs,
                upgradedBounty.totalRewardAmount,
                upgradedBounty.maxRewardPerVote
            );

            // Reset the next values.
            delete upgradeBountyQueue[bountyId];
        }
    }

    /// @notice Roll over to next period.
    /// @param bountyId Bounty ID.
    /// @param currentEpoch Next period timestamp.
    /// @param proofData User's proof data
    function _rollOverToNextPeriod(uint256 bountyId, uint256 currentEpoch, ProofData memory proofData) internal {
        uint8 index = getActivePeriodPerBounty(bountyId);

        Bounty storage bounty = bounties[bountyId];

        uint256 periodsLeft = getPeriodsLeft(bountyId);
        uint256 rewardPerPeriod;

        rewardPerPeriod = bounty.totalRewardAmount - amountClaimed[bountyId];

        if (bounty.endTimestamp > currentEpoch + _TWOWEEKS && periodsLeft > 1) {
            rewardPerPeriod = rewardPerPeriod.mulDiv(1, periodsLeft);
        }

        // Get adjusted slope without blacklisted addresses.
        uint256 gaugeBias = _getAdjustedBias(bounty.gauge, bounty.chainId, bounty.blacklist, currentEpoch, proofData);

        rewardPerVote[bountyId] = rewardPerPeriod.mulDiv(_BASE_UNIT, gaugeBias);
        activePeriod[bountyId] = Period(index, currentEpoch, rewardPerPeriod);

        emit PeriodRolledOver(bountyId, index, currentEpoch, rewardPerPeriod);
    }

    /// @notice Update the amount of reward per token for a given bounty.
    /// @dev This function is only called once per Bounty.
    /// @param bountyId Bounty ID.
    /// @param currentEpoch Next period timestamp.
    /// @param proofData User proof data
    function _updateRewardPerToken(uint256 bountyId, uint256 currentEpoch, ProofData memory proofData) internal {
        Bounty storage bounty = bounties[bountyId];

        uint256 gaugeBias = _getAdjustedBias(bounty.gauge, bounty.chainId, bounty.blacklist, currentEpoch, proofData);

        if (gaugeBias != 0) {
            rewardPerVote[bountyId] = activePeriod[bountyId].rewardPerPeriod.mulDiv(_BASE_UNIT, gaugeBias);
        }
    }

    ////////////////////////////////////////////////////////////////
    /// ---  VIEWS
    ///////////////////////////////////////////////////////////////

    /// @notice Get an estimate of the reward amount for a given user.
    /// @param bountyId ID of the bounty.
    /// @param proofUserVote User vote proof.
    /// @param proofProxyVote Proxy vote proof.
    /// @dev Returns only claimable for current week. For previous weeks rewards, if it was checkpointed, use `checkpointedBalances`
    /// @return amount of rewards.
    /// Mainly used for UI.
    function claimable(uint256 bountyId, ProofData memory proofUserVote, ProofData memory proofProxyVote)
        external
        view
        returns (uint256 amount)
    {
        if (proofProxyVote.user != address(0)) {
            amount += _activeClaimable(proofProxyVote, bountyId);
        }

        amount += _activeClaimable(proofUserVote, bountyId);
    }

    ////////////////////////////////////////////////////////////////
    /// --- INTERNAL VIEWS
    ///////////////////////////////////////////////////////////////

    /// @notice Get adjusted slope from Gauge Controller for a given gauge address.
    /// Remove the weight of blacklisted addresses.
    /// @param gauge Address of the gauge.
    /// @param chainId chain id
    /// @param _addressesBlacklisted Array of blacklisted addresses.
    /// @param period   Timestamp to check vote weight.
    function _getAdjustedBias(
        address gauge,
        uint256 chainId,
        address[] memory _addressesBlacklisted,
        uint256 period,
        ProofData memory proofData
    ) internal returns (uint256 gaugeBias) {
        uint256 snapshotBlock = gaugeController.last_eth_block_number();

        if (gaugeAdjustedBias[gauge][snapshotBlock] != 0) {
            return gaugeAdjustedBias[gauge][snapshotBlock];
        }

        // Cache the user slope.
        IGaugeVotingOracle.VotedSlope memory userSlope;
        // Bias
        uint256 _bias;
        // Cache the length of the array.
        uint256 length = _addressesBlacklisted.length;
        // Get the gauge slope.
        gaugeBias = gaugeController.pointWeights(gauge, snapshotBlock).bias;

        if (gaugeBias == 0) {
            gaugeController.submit_state(proofData.user, gauge, chainId, proofData.headerRlp, proofData.userProofRlp);

            if (!gaugeController.isUserUpdated(snapshotBlock, proofData.user, gauge)) {
                revert USER_NOT_UPDATED();
            }

            gaugeBias = gaugeController.pointWeights(gauge, snapshotBlock).bias;
        }

        if (length > 0) {
            for (uint256 i = 0; i < length;) {
                // Get the user slope.
                userSlope = _submitState(
                    _addressesBlacklisted[i],
                    gauge,
                    chainId,
                    proofData.headerRlp,
                    proofData.blackListedProofsRlp[i],
                    snapshotBlock
                );
                // Remove the user bias from the gauge bias.
                _bias = _getAddrBias(userSlope.slope, userSlope.end, period);

                gaugeBias -= _bias;

                unchecked {
                    // Increment i.
                    ++i;
                }
            }
        }

        gaugeAdjustedBias[gauge][snapshotBlock] = gaugeBias;
    }

    function _submitState(
        address _user,
        address _gauge,
        uint256 _chainId,
        bytes memory _headerRlp,
        bytes memory _proofRlp,
        uint256 snapshotBlock
    ) internal returns (IGaugeVotingOracle.VotedSlope memory slope) {
        if (!gaugeController.isUserUpdated(snapshotBlock, _user, _gauge)) {
            gaugeController.submit_state(_user, _gauge, _chainId, _headerRlp, _proofRlp);
            if (!gaugeController.isUserUpdated(snapshotBlock, _user, _gauge)) {
                revert USER_NOT_UPDATED();
            }
        }
        slope = gaugeController.voteUserSlope(snapshotBlock, _user, _gauge);
    }

    ////////////////////////////////////////////////////////////////
    /// --- MANAGEMENT LOGIC
    ///////////////////////////////////////////////////////////////

    /// @notice Increase Bounty duration.
    /// @param _bountyId ID of the bounty.
    /// @param _additionnalEpochs Number of epochs to add.
    /// @param _increasedAmount Total reward amount to add.
    /// @param _newMaxPricePerVote Total reward amount to add.
    function increaseBountyDuration(
        uint256 _bountyId,
        uint8 _additionnalEpochs,
        uint256 _increasedAmount,
        uint256 _newMaxPricePerVote
    ) external nonReentrant notKilled onlyManager(_bountyId) {
        if (!isUpgradeable[_bountyId]) revert NOT_UPGRADEABLE();
        if (getPeriodsLeft(_bountyId) < 1) revert NO_PERIODS_LEFT();
        if (_increasedAmount == 0 || _newMaxPricePerVote == 0) {
            revert WRONG_INPUT();
        }

        Bounty storage bounty = bounties[_bountyId];
        Upgrade memory upgradedBounty = upgradeBountyQueue[_bountyId];

        SafeTransferLib.safeTransferFrom(bounty.rewardToken, msg.sender, address(this), _increasedAmount);

        if (upgradedBounty.totalRewardAmount != 0) {
            upgradedBounty = Upgrade({
                numberOfEpochs: upgradedBounty.numberOfEpochs + _additionnalEpochs,
                totalRewardAmount: upgradedBounty.totalRewardAmount + _increasedAmount,
                maxRewardPerVote: _newMaxPricePerVote,
                endTimestamp: upgradedBounty.endTimestamp + (_additionnalEpochs * _TWOWEEKS)
            });
        } else {
            upgradedBounty = Upgrade({
                numberOfEpochs: bounty.numberOfEpochs + _additionnalEpochs,
                totalRewardAmount: bounty.totalRewardAmount + _increasedAmount,
                maxRewardPerVote: _newMaxPricePerVote,
                endTimestamp: bounty.endTimestamp + (_additionnalEpochs * _TWOWEEKS)
            });
        }

        upgradeBountyQueue[_bountyId] = upgradedBounty;

        emit BountyDurationIncreaseQueued(
            _bountyId, upgradedBounty.numberOfEpochs, upgradedBounty.totalRewardAmount, _newMaxPricePerVote
        );
    }

    /// @notice Close Bounty if there is remaining.
    /// @param bountyId ID of the bounty to close.
    function closeBounty(uint256 bountyId) external nonReentrant {
        // Check if the currentEpoch is the last one.
        // If not, we can increase the duration.
        Bounty storage bounty = bounties[bountyId];
        if (bounty.manager == address(0)) revert ALREADY_CLOSED();

        // Check if there is an upgrade in queue and update the bounty.
        _checkForUpgrade(bountyId);

        if (getCurrentEpoch() >= bounty.endTimestamp || isKilled) {
            uint256 leftOver;
            Upgrade memory upgradedBounty = upgradeBountyQueue[bountyId];

            if (upgradedBounty.totalRewardAmount != 0) {
                leftOver = upgradedBounty.totalRewardAmount - amountClaimed[bountyId];
                delete upgradeBountyQueue[bountyId];
            } else {
                leftOver = bounties[bountyId].totalRewardAmount - amountClaimed[bountyId];
            }

            // Transfer the left over to the owner.
            SafeTransferLib.safeTransfer(bounty.rewardToken, bounty.manager, leftOver);
            delete bounties[bountyId].manager;

            emit BountyClosed(bountyId, leftOver);
        }
    }

    /// @notice Update Bounty Manager.
    /// @param bountyId ID of the bounty.
    /// @param newManager Address of the new manager.
    function updateManager(uint256 bountyId, address newManager) external onlyManager(bountyId) {
        if (newManager == address(0)) revert ZERO_ADDRESS();

        emit ManagerUpdated(bountyId, bounties[bountyId].manager = newManager);
    }

    ////////////////////////////////////////////////////////////////
    /// --- ONLY OWNER FUNCTIONS
    ///////////////////////////////////////////////////////////////

    /// @notice Claim fees.
    /// @param rewardTokens Array of reward tokens.
    function claimFees(address[] calldata rewardTokens) external nonReentrant {
        if (feeCollector == address(0)) revert ZERO_ADDRESS();

        uint256 _feeAccrued;
        uint256 length = rewardTokens.length;

        for (uint256 i = 0; i < length;) {
            address rewardToken = rewardTokens[i];

            _feeAccrued = feeAccrued[rewardToken];
            delete feeAccrued[rewardToken];

            emit FeesCollected(rewardToken, _feeAccrued);

            SafeTransferLib.safeTransfer(rewardToken, feeCollector, _feeAccrued);

            unchecked {
                i++;
            }
        }
    }

    /// @notice Set the platform fee.
    /// @param _platformFee Platform fee.
    function setPlatformFee(uint256 _platformFee) external onlyOwner {
        if (_platformFee > 1e18) revert WRONG_INPUT();

        fee = _platformFee;

        emit FeeUpdated(_platformFee);
    }

    /// @notice Set the fee collector.
    /// @param _feeCollector Address of the fee collector.
    function setFeeCollector(address _feeCollector) external onlyOwner {
        feeCollector = _feeCollector;

        emit FeeCollectorUpdated(_feeCollector);
    }

    /// @notice Set the gauge controller (oracle).
    /// @param _gaugeController Address of the gauge controller.
    function setGaugeController(address _gaugeController) external onlyOwner {
        gaugeController = IGaugeVotingOracle(_gaugeController);

        emit GaugeControllerUpdated(_gaugeController);
    }

    /// @notice Set the recipient for a given address.
    /// @param _for Address to set the recipient for.
    /// @param _recipient Address of the recipient.
    function setRecipientFor(address _for, address _recipient) external onlyOwner {
        recipient[_for] = _recipient;

        emit RecipientSet(_for, _recipient);
    }

    /// @notice Kill the platform
    function kill() external onlyOwner {
        isKilled = true;
    }

    /// @notice Whitelist or delist and address
    /// @param _address Address to toggle
    /// @param _isWhitelist If whitelist or delist an address
    function whitelistAddress(address _address, bool _isWhitelist) external onlyOwner {
        whitelisted[_address] = _isWhitelist;
    }

    ////////////////////////////////////////////////////////////////
    /// --- UTILS FUNCTIONS
    ///////////////////////////////////////////////////////////////

    /// @notice Returns the number of periods left for a given bounty.
    /// @param bountyId ID of the bounty.
    function getPeriodsLeft(uint256 bountyId) public view returns (uint256 periodsLeft) {
        Bounty storage bounty = bounties[bountyId];

        uint256 currentEpoch = getCurrentEpoch();
        periodsLeft = bounty.endTimestamp > currentEpoch ? (bounty.endTimestamp - currentEpoch) / _TWOWEEKS : 0;
    }

    /// @notice Return the bounty object for a given ID.
    /// @param bountyId ID of the bounty.
    function getBounty(uint256 bountyId) external view returns (Bounty memory) {
        return bounties[bountyId];
    }

    /// @notice Return the bounty in queue for a given ID.
    /// @dev Can return an empty bounty if there is no upgrade.
    /// @param bountyId ID of the bounty.
    function getUpgradedBountyQueued(uint256 bountyId) external view returns (Upgrade memory) {
        return upgradeBountyQueue[bountyId];
    }

    /// @notice Return the blacklisted addresses of a bounty for a given ID.
    /// @param bountyId ID of the bounty.
    function getBlacklistedAddressesPerBounty(uint256 bountyId) external view returns (address[] memory) {
        return bounties[bountyId].blacklist;
    }

    /// @notice Return the active epoch running of bounty given an ID.
    /// @param bountyId ID of the bounty.
    function getActivePeriod(uint256 bountyId) public view returns (Period memory) {
        return activePeriod[bountyId];
    }

    /// @notice Return the expected current period id.
    /// @param bountyId ID of the bounty.
    function getActivePeriodPerBounty(uint256 bountyId) public view returns (uint8) {
        Bounty storage bounty = bounties[bountyId];

        uint256 currentEpoch = getCurrentEpoch();
        uint256 periodsLeft = bounty.endTimestamp > currentEpoch ? (bounty.endTimestamp - currentEpoch) / _TWOWEEKS : 0;
        // If periodsLeft is superior, then the bounty didn't start yet.
        return uint8(periodsLeft > bounty.numberOfEpochs ? 0 : bounty.numberOfEpochs - periodsLeft);
    }

    /// @notice Return the current voting period
    /// @dev According with realPeriod of Gauge Voting contract, which should be even weeks Thursday
    function getCurrentEpoch() public view returns (uint256) {
        return (block.timestamp / _TWOWEEKS) * _TWOWEEKS;
    }

    /// @notice Return the bias of a given address based on its lock end date and the current period.
    /// @param userSlope User slope.
    /// @param endLockTime Lock end date of the address.
    /// @param currentEpoch Current period.
    function _getAddrBias(uint256 userSlope, uint256 endLockTime, uint256 currentEpoch)
        internal
        pure
        returns (uint256)
    {
        if (currentEpoch >= endLockTime) return 0;
        return userSlope * (endLockTime - currentEpoch);
    }

    /// @notice Get the claimable amount for a user and a bounty.
    function _activeClaimable(ProofData memory proofData, uint256 bountyId) internal view returns (uint256 amount) {
        if (isBlacklisted[bountyId][proofData.user]) return 0;

        uint256 currentEpoch = getCurrentEpoch();

        if (currentEpoch != gaugeController.activePeriod()) return 0;

        Bounty memory bounty = bounties[bountyId];

        // If there is an upgrade in progress but period hasn't been rolled over yet.
        Upgrade storage upgradedBounty = upgradeBountyQueue[bountyId];

        // End timestamp of the bounty.
        uint256 endTimestamp = FixedPointMathLib.max(bounty.endTimestamp, upgradedBounty.endTimestamp);

        uint256 lastVote;
        IGaugeVotingOracle.Point memory gaugeBias;
        IGaugeVotingOracle.VotedSlope memory userSlope;

        // use gauge hash to extract proof
        bytes32 gaugeHash = keccak256(abi.encodePacked(bounty.gauge, bounty.chainId));

        (gaugeBias, userSlope, lastVote,) =
            gaugeController.extractProofState(proofData.user, bounty.gauge, proofData.headerRlp, proofData.userProofRlp);

        if (
            userSlope.slope == 0 || lastUserClaim[proofData.user][bountyId] >= currentEpoch
                || currentEpoch >= userSlope.end || currentEpoch <= lastVote || currentEpoch >= endTimestamp
                || currentEpoch < getActivePeriod(bountyId).timestamp || amountClaimed[bountyId] >= bounty.totalRewardAmount
        ) return 0;

        uint256 _rewardPerVote = rewardPerVote[bountyId];

        // If period updated.
        if (_rewardPerVote == 0 || (_rewardPerVote > 0 && getActivePeriod(bountyId).timestamp != currentEpoch)) {
            uint256 _rewardPerPeriod;

            if (upgradedBounty.numberOfEpochs != 0) {
                // Update max reward per vote.
                bounty.maxRewardPerVote = upgradedBounty.maxRewardPerVote;
                bounty.totalRewardAmount = upgradedBounty.totalRewardAmount;
            }

            uint256 periodsLeft = endTimestamp > currentEpoch ? (endTimestamp - currentEpoch) / _TWOWEEKS : 0;

            _rewardPerPeriod = bounty.totalRewardAmount - amountClaimed[bountyId];

            // Update reward per period if we're on the week after the active period
            if (endTimestamp > currentEpoch + _TWOWEEKS && periodsLeft > 1) {
                _rewardPerPeriod = _rewardPerPeriod.mulDiv(1, periodsLeft);
            }

            _rewardPerVote = _rewardPerPeriod.mulDiv(
                _BASE_UNIT,
                // Get Adjusted Slope without blacklisted addresses weight or just weight if not set yet.
                gaugeAdjustedBias[bounty.gauge][gaugeController.last_eth_block_number()] > 0
                    ? gaugeAdjustedBias[bounty.gauge][gaugeController.last_eth_block_number()]
                    : gaugeBias.bias
            );
        }
        // Get user voting power.
        uint256 _bias = _getAddrBias(userSlope.slope, userSlope.end, currentEpoch);

        // Estimation of the amount of rewards.
        amount = _bias.mulWad(_rewardPerVote);
        // Compute the reward amount based on
        // the max price to pay.
        uint256 _amountWithMaxPrice = _bias.mulWad(bounty.maxRewardPerVote);
        // Distribute the _min between the amount based on votes, and price.
        amount = FixedPointMathLib.min(amount, _amountWithMaxPrice);

        uint256 _amountClaimed = amountClaimed[bountyId];
        // Update the amount claimed.
        if (amount + _amountClaimed > bounty.totalRewardAmount) {
            amount = bounty.totalRewardAmount - _amountClaimed;
        }
        // Substract fees.
        if (fee != 0) {
            amount = amount.mulWad(_BASE_UNIT - fee);
        }
    }

    function getVersion() external pure returns (string memory) {
        return "2.2.1";
    }
}
