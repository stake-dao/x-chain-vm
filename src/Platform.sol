// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;
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
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IGaugeControllerOracle} from "src/interfaces/IGaugeControllerOracle.sol";

/// @title  Platform
/// @author Stake DAO
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
        // Manager.
        address manager;
        // Address of the ERC20 used for rewards.
        address rewardToken;
        // Number of periods.
        uint8 numberOfPeriods;
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
        // Number of periods after increase.
        uint8 numberOfPeriods;
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
    uint8 public constant MINIMUM_PERIOD = 2;

    /// @notice Week in seconds.
    uint256 private constant _WEEK = 1 weeks;

    /// @notice Base unit for fixed point compute.
    uint256 private constant _BASE_UNIT = 1e18;

    /// @notice Default fee.
    uint256 internal constant _DEFAULT_FEE = 2e16; // 2%

    /// @notice Gauge Controller.
    IGaugeControllerOracle public gaugeController;

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
    error NOT_UPGRADEABLE();
    error NO_PERIODS_LEFT();
    error USER_NOT_UPDATED();
    error AUTH_MANAGER_ONLY();
    error INVALID_NUMBER_OF_PERIODS();
    error NO_RECEIVER_SET_FOR_WHITELISTED();
    ////////////////////////////////////////////////////////////////
    /// --- CONSTRUCTOR
    ///////////////////////////////////////////////////////////////

    /// @notice Create Bounty platform.
    /// @param _gaugeController Address of the gauge controller.
    constructor(address _gaugeController, address _feeCollector, address _owner) Owned(_owner) {
        fee = _DEFAULT_FEE;
        feeCollector = _feeCollector;
        gaugeController = IGaugeControllerOracle(_gaugeController);
    }

    ////////////////////////////////////////////////////////////////
    /// --- BOUNTY CREATION LOGIC
    ///////////////////////////////////////////////////////////////

    /// @notice Create a new bounty.
    /// @param gauge Address of the target gauge.
    /// @param rewardToken Address of the ERC20 used or rewards.
    /// @param numberOfPeriods Number of periods.
    /// @param maxRewardPerVote Target Bias for the Gauge.
    /// @param totalRewardAmount Total Reward Added.
    /// @param blacklist Array of addresses to blacklist.
    /// @return newBountyId of the bounty created.
    function createBounty(
        address gauge,
        address manager,
        address rewardToken,
        uint8 numberOfPeriods,
        uint256 maxRewardPerVote,
        uint256 totalRewardAmount,
        address[] calldata blacklist,
        bool upgradeable
    ) external nonReentrant notKilled returns (uint256 newBountyId) {
        if (numberOfPeriods < MINIMUM_PERIOD) revert INVALID_NUMBER_OF_PERIODS();
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

        uint256 rewardPerPeriod = totalRewardAmount.mulDiv(1, numberOfPeriods);
        uint256 currentPeriod = getCurrentPeriod();

        bounties[newBountyId] = Bounty({
            gauge: gauge,
            manager: manager,
            rewardToken: rewardToken,
            numberOfPeriods: numberOfPeriods,
            endTimestamp: currentPeriod + ((numberOfPeriods + 1) * _WEEK),
            maxRewardPerVote: maxRewardPerVote,
            totalRewardAmount: totalRewardAmount,
            blacklist: blacklist
        });

        emit BountyCreated(
            newBountyId,
            gauge,
            manager,
            rewardToken,
            numberOfPeriods,
            maxRewardPerVote,
            rewardPerPeriod,
            totalRewardAmount,
            upgradeable
        );

        // Set Upgradeable status.
        isUpgradeable[newBountyId] = upgradeable;
        // Starting from next period.
        activePeriod[newBountyId] = Period(0, currentPeriod + _WEEK, rewardPerPeriod);

        // Add the addresses to the blacklist.
        uint256 length = blacklist.length;
        for (uint256 i = 0; i < length;) {
            isBlacklisted[newBountyId][blacklist[i]] = true;
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Claim rewards for a given bounty.
    /// @param bountyId ID of the bounty.
    /// @return Amount of rewards claimed.
    function claim(uint256 bountyId, ProofData memory proofData) external returns (uint256) {
        return _claim(bountyId, proofData);
    }

    /// @notice Claim all rewards for multiple bounties.
    /// @param ids Array of bounty IDs to claim.
    function claimAll(uint256[] calldata ids, ProofData[] calldata proofs) external {
        uint256 length = ids.length;

        for (uint256 i = 0; i < length;) {
            uint256 id = ids[i];
            _claim(id, proofs[i]);

            unchecked {
                ++i;
            }
        }
    }

    ////////////////////////////////////////////////////////////////
    /// --- INTERNAL LOGIC
    ///////////////////////////////////////////////////////////////

    /// @notice Claim rewards for a given bounty.
    /// @param _bountyId ID of the bounty.
    /// @return amount of rewards claimed.
    function _claim(uint256 _bountyId, ProofData memory proofData)
        internal
        nonReentrant
        notKilled
        returns (uint256 amount)
    {
        if (isBlacklisted[_bountyId][proofData.user]) return 0;
        // Update if needed the current period.
        uint256 currentPeriod = _updateBountyPeriod(_bountyId, proofData);
        uint256 snapshotBlock = gaugeController.last_eth_block_number();

        if (currentPeriod != gaugeController.activePeriod()) return 0;

        Bounty storage bounty = bounties[_bountyId];

        IGaugeControllerOracle.VotedSlope memory userSlope;
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
            userSlope.slope == 0 || lastUserClaim[proofData.user][_bountyId] >= currentPeriod
                || currentPeriod >= userSlope.end || currentPeriod <= lastVote || currentPeriod >= bounty.endTimestamp
                || currentPeriod != getCurrentPeriod() || amountClaimed[_bountyId] == bounty.totalRewardAmount
        ) return 0;

        // Update User last claim period.
        lastUserClaim[proofData.user][_bountyId] = currentPeriod;

        // Voting Power = userSlope * dt
        // with dt = lock_end - period.
        uint256 _bias = _getAddrBias(userSlope.slope, userSlope.end, currentPeriod);
        // Compute the reward amount based on
        // Reward / Total Votes.
        amount = _bias.mulWad(rewardPerVote[_bountyId]);
        // Compute the reward amount based on
        // the max price to pay.
        uint256 _amountWithMaxPrice = _bias.mulWad(bounty.maxRewardPerVote);
        // Distribute the _min between the amount based on votes, and price.
        amount = FixedPointMathLib.min(amount, _amountWithMaxPrice);

        // Update the amount claimed.
        uint256 _amountClaimed = amountClaimed[_bountyId];

        if (amount + _amountClaimed > bounty.totalRewardAmount) {
            amount = bounty.totalRewardAmount - _amountClaimed;
        }

        amountClaimed[_bountyId] += amount;

        uint256 feeAmount;
        if (fee != 0) {
            feeAmount = amount.mulWad(fee);
            amount -= feeAmount;
            feeAccrued[bounty.rewardToken] += feeAmount;
        }

        address receiver = gaugeController.recipient(proofData.user);
        if (whitelisted[proofData.user] && receiver == address(0)) revert NO_RECEIVER_SET_FOR_WHITELISTED();
        receiver = receiver != address(0) ? receiver : proofData.user;

        // Transfer to user.
        SafeTransferLib.safeTransfer(bounty.rewardToken, receiver, amount);

        emit Claimed(proofData.user, bounty.rewardToken, _bountyId, amount, feeAmount, currentPeriod);
    }

    /// @notice Update the current period for a given bounty.
    /// @param bountyId Bounty ID.
    /// @return current/updated period.
    function _updateBountyPeriod(uint256 bountyId, ProofData memory proofData) internal returns (uint256) {
        Period storage _activePeriod = activePeriod[bountyId];

        uint256 currentPeriod = getCurrentPeriod();

        if (_activePeriod.id == 0 && currentPeriod == _activePeriod.timestamp && rewardPerVote[bountyId] == 0) {
            // Check if there is an upgrade in queue and update the bounty.
            _checkForUpgrade(bountyId);

            // Initialize reward per token.
            // Only for the first period, and if not already initialized.
            _updateRewardPerToken(bountyId, currentPeriod, proofData);
        }

        // Increase Period
        if (block.timestamp >= _activePeriod.timestamp + _WEEK) {
            // Check if there is an upgrade in queue and update the bounty.
            _checkForUpgrade(bountyId);

            // Roll to next period.
            _rollOverToNextPeriod(bountyId, currentPeriod, proofData);

            return currentPeriod;
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
            bounties[bountyId].numberOfPeriods = upgradedBounty.numberOfPeriods;
            bounties[bountyId].maxRewardPerVote = upgradedBounty.maxRewardPerVote;
            bounties[bountyId].totalRewardAmount = upgradedBounty.totalRewardAmount;

            if (activePeriod[bountyId].id == 0) {
                activePeriod[bountyId].rewardPerPeriod =
                    upgradedBounty.totalRewardAmount.mulDiv(1, upgradedBounty.numberOfPeriods);
            }

            emit BountyDurationIncrease(
                bountyId,
                upgradedBounty.numberOfPeriods,
                upgradedBounty.totalRewardAmount,
                upgradedBounty.maxRewardPerVote
            );

            // Reset the next values.
            delete upgradeBountyQueue[bountyId];
        }
    }

    /// @notice Roll over to next period.
    /// @param bountyId Bounty ID.
    /// @param currentPeriod Next period timestamp.
    function _rollOverToNextPeriod(uint256 bountyId, uint256 currentPeriod, ProofData memory proofData) internal {
        uint8 index = getActivePeriodPerBounty(bountyId);

        Bounty storage bounty = bounties[bountyId];

        uint256 periodsLeft = getPeriodsLeft(bountyId);
        uint256 rewardPerPeriod;

        rewardPerPeriod = bounty.totalRewardAmount - amountClaimed[bountyId];

        if (bounty.endTimestamp > currentPeriod + _WEEK && periodsLeft > 1) {
            rewardPerPeriod = rewardPerPeriod.mulDiv(1, periodsLeft);
        }

        // Get adjusted slope without blacklisted addresses.
        uint256 gaugeBias = _getAdjustedBias(bounty.gauge, bounty.blacklist, currentPeriod, proofData);

        rewardPerVote[bountyId] = rewardPerPeriod.mulDiv(_BASE_UNIT, gaugeBias);
        activePeriod[bountyId] = Period(index, currentPeriod, rewardPerPeriod);

        emit PeriodRolledOver(bountyId, index, currentPeriod, rewardPerPeriod);
    }

    /// @notice Update the amount of reward per token for a given bounty.
    /// @dev This function is only called once per Bounty.
    function _updateRewardPerToken(uint256 bountyId, uint256 currentPeriod, ProofData memory proofData) internal {
        if (rewardPerVote[bountyId] == 0) {
            uint256 gaugeBias =
                _getAdjustedBias(bounties[bountyId].gauge, bounties[bountyId].blacklist, currentPeriod, proofData);

            if (gaugeBias != 0) {
                rewardPerVote[bountyId] = activePeriod[bountyId].rewardPerPeriod.mulDiv(_BASE_UNIT, gaugeBias);
            }
        }
    }

    ////////////////////////////////////////////////////////////////
    /// ---  VIEWS
    ///////////////////////////////////////////////////////////////

    // /// @notice Get an estimate of the reward amount for a given user.
    // /// @param user Address of the user.
    // /// @param bountyId ID of the bounty.
    // /// @return amount of rewards.
    /// Mainly used for UI.
    function claimable(uint256 bountyId, ProofData memory proofData) external view returns (uint256 amount) {
        if (isBlacklisted[bountyId][proofData.user]) return 0;
        // Update if needed the current period.
        uint256 currentPeriod = getCurrentPeriod();

        if (currentPeriod != gaugeController.activePeriod()) return 0;

        Bounty memory bounty = bounties[bountyId];

        // If there is an upgrade in progress but period hasn't been rolled over yet.
        Upgrade storage upgradedBounty = upgradeBountyQueue[bountyId];

        // End timestamp of the bounty.
        uint256 endTimestamp = FixedPointMathLib.max(bounty.endTimestamp, upgradedBounty.endTimestamp);

        uint256 lastVote;
        IGaugeControllerOracle.Point memory gaugeBias;
        IGaugeControllerOracle.VotedSlope memory userSlope;

        (gaugeBias, userSlope, lastVote,) =
            gaugeController.extractProofState(proofData.user, bounty.gauge, proofData.headerRlp, proofData.userProofRlp);

        if (
            userSlope.slope == 0 || lastUserClaim[proofData.user][bountyId] >= currentPeriod
                || currentPeriod >= userSlope.end || currentPeriod <= lastVote || currentPeriod >= bounty.endTimestamp
                || currentPeriod < getActivePeriod(bountyId).timestamp
                || amountClaimed[bountyId] >= bounty.totalRewardAmount
        ) return 0;

        uint256 _rewardPerVote = rewardPerVote[bountyId];
        // If period updated.
        if (_rewardPerVote == 0 || (_rewardPerVote > 0 && getActivePeriod(bountyId).timestamp != currentPeriod)) {
            uint256 _rewardPerPeriod;

            if (upgradedBounty.numberOfPeriods != 0) {
                // Update max reward per vote.
                bounty.maxRewardPerVote = upgradedBounty.maxRewardPerVote;
                bounty.totalRewardAmount = upgradedBounty.totalRewardAmount;
            }

            uint256 periodsLeft = endTimestamp > currentPeriod ? (endTimestamp - currentPeriod) / _WEEK : 0;
            _rewardPerPeriod = bounty.totalRewardAmount - amountClaimed[bountyId];

            if (endTimestamp > currentPeriod + _WEEK && periodsLeft > 1) {
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
        uint256 _bias = _getAddrBias(userSlope.slope, userSlope.end, currentPeriod);
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

    ////////////////////////////////////////////////////////////////
    /// --- INTERNAL VIEWS
    ///////////////////////////////////////////////////////////////

    /// @notice Get adjusted slope from Gauge Controller for a given gauge address.
    /// Remove the weight of blacklisted addresses.
    /// @param gauge Address of the gauge.
    /// @param _addressesBlacklisted Array of blacklisted addresses.
    /// @param period   Timestamp to check vote weight.
    function _getAdjustedBias(
        address gauge,
        address[] memory _addressesBlacklisted,
        uint256 period,
        ProofData memory proofData
    ) internal returns (uint256 gaugeBias) {
        uint256 snapshotBlock = gaugeController.last_eth_block_number();

        if (gaugeAdjustedBias[gauge][snapshotBlock] != 0) {
            return gaugeAdjustedBias[gauge][snapshotBlock];
        }

        // Cache the user slope.
        IGaugeControllerOracle.VotedSlope memory userSlope;
        // Bias
        uint256 _bias;
        // Cache the length of the array.
        uint256 length = _addressesBlacklisted.length;
        // Get the gauge slope.
        gaugeBias = gaugeController.pointWeights(gauge, snapshotBlock).bias;

        if (gaugeBias == 0) {
            gaugeController.submit_state(proofData.user, gauge, proofData.headerRlp, proofData.userProofRlp);

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
        bytes memory _headerRlp,
        bytes memory _proofRlp,
        uint256 snapshotBlock
    ) internal returns (IGaugeControllerOracle.VotedSlope memory slope) {
        if (!gaugeController.isUserUpdated(snapshotBlock, _user, _gauge)) {
            gaugeController.submit_state(_user, _gauge, _headerRlp, _proofRlp);
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
    /// @param _additionnalPeriods Number of periods to add.
    /// @param _increasedAmount Total reward amount to add.
    /// @param _newMaxPricePerVote Total reward amount to add.
    function increaseBountyDuration(
        uint256 _bountyId,
        uint8 _additionnalPeriods,
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
                numberOfPeriods: upgradedBounty.numberOfPeriods + _additionnalPeriods,
                totalRewardAmount: upgradedBounty.totalRewardAmount + _increasedAmount,
                maxRewardPerVote: _newMaxPricePerVote,
                endTimestamp: upgradedBounty.endTimestamp + (_additionnalPeriods * _WEEK)
            });
        } else {
            upgradedBounty = Upgrade({
                numberOfPeriods: bounty.numberOfPeriods + _additionnalPeriods,
                totalRewardAmount: bounty.totalRewardAmount + _increasedAmount,
                maxRewardPerVote: _newMaxPricePerVote,
                endTimestamp: bounty.endTimestamp + (_additionnalPeriods * _WEEK)
            });
        }

        upgradeBountyQueue[_bountyId] = upgradedBounty;

        emit BountyDurationIncreaseQueued(
            _bountyId, upgradedBounty.numberOfPeriods, upgradedBounty.totalRewardAmount, _newMaxPricePerVote
        );
    }

    /// @notice Close Bounty if there is remaining.
    /// @param bountyId ID of the bounty to close.
    function closeBounty(uint256 bountyId) external nonReentrant {
        // Check if the currentPeriod is the last one.
        // If not, we can increase the duration.
        Bounty storage bounty = bounties[bountyId];
        if (bounty.manager == address(0)) revert ALREADY_CLOSED();

        // Check if there is an upgrade in queue and update the bounty.
        _checkForUpgrade(bountyId);

        if (getCurrentPeriod() >= bounty.endTimestamp || isKilled) {
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

    function kill() external onlyOwner {
        isKilled = true;
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
        gaugeController = IGaugeControllerOracle(_gaugeController);

        emit GaugeControllerUpdated(_gaugeController);
    }

    /// @notice Set the recipient for a given address.
    /// @param _for Address to set the recipient for.
    /// @param _recipient Address of the recipient.
    function setRecipientFor(address _for, address _recipient) external onlyOwner {
        recipient[_for] = _recipient;

        emit RecipientSet(_for, _recipient);
    }

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

        uint256 currentPeriod = getCurrentPeriod();
        periodsLeft = bounty.endTimestamp > currentPeriod ? (bounty.endTimestamp - currentPeriod) / _WEEK : 0;
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

    /// @notice Return the active period running of bounty given an ID.
    /// @param bountyId ID of the bounty.
    function getActivePeriod(uint256 bountyId) public view returns (Period memory) {
        return activePeriod[bountyId];
    }

    /// @notice Return the expected current period id.
    /// @param bountyId ID of the bounty.
    function getActivePeriodPerBounty(uint256 bountyId) public view returns (uint8) {
        Bounty storage bounty = bounties[bountyId];

        uint256 currentPeriod = getCurrentPeriod();
        uint256 periodsLeft = bounty.endTimestamp > currentPeriod ? (bounty.endTimestamp - currentPeriod) / _WEEK : 0;
        // If periodsLeft is superior, then the bounty didn't start yet.
        return uint8(periodsLeft > bounty.numberOfPeriods ? 0 : bounty.numberOfPeriods - periodsLeft);
    }

    /// @notice Return the current period based on Gauge Controller rounding.
    function getCurrentPeriod() public view returns (uint256) {
        return (block.timestamp / _WEEK) * _WEEK;
    }

    /// @notice Return the bias of a given address based on its lock end date and the current period.
    /// @param userSlope User slope.
    /// @param endLockTime Lock end date of the address.
    /// @param currentPeriod Current period.
    function _getAddrBias(uint256 userSlope, uint256 endLockTime, uint256 currentPeriod)
        internal
        pure
        returns (uint256)
    {
        if (currentPeriod >= endLockTime) return 0;
        return userSlope * (endLockTime - currentPeriod);
    }

    function getVersion() external pure returns (string memory) {
        return "2.4.0";
    }
}
