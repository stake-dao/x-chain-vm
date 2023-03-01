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

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

import {ICurveGaugeControllerOracle} from "src/interfaces/ICurveGaugeControllerOracle.sol";

/// version 1.0.0
/// @title  Platform
/// @author Stake DAO
contract Platform is ReentrancyGuard {
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

    /// @notice Bribe struct requirements.
    struct Bribe {
        // Address of the target gauge.
        address gauge;
        // Manager.
        address manager;
        // Address of the ERC20 used for rewards.
        address rewardToken;
        // Number of periods.
        uint8 numberOfPeriods;
        // Timestamp where the bribe become unclaimable.
        uint256 endTimestamp;
        // Max Price per vote.
        uint256 maxRewardPerVote;
        // Total Reward Added.
        uint256 totalRewardAmount;
        // Blacklisted addresses.
        address[] blacklist;
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

    struct Upgrade {
        // Number of periods after increase.
        uint8 numberOfPeriods;
        // Total reward amount after increase.
        uint256 totalRewardAmount;
        // New max reward per vote after increase.
        uint256 maxRewardPerVote;
        // New end timestamp after increase.
        uint256 endTimestamp;
        // Blacklisted addresses.
        address[] blacklist;
    }

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

    /// @notice Week in seconds.
    uint256 private constant _WEEK = 1 weeks;

    /// @notice Base unit for fixed point compute.
    uint256 private constant _BASE_UNIT = 1e18;

    /// @notice Minimum duration a Bribe.
    uint8 public constant MINIMUM_PERIOD = 2;

    /// @notice Curve Gauge Controller Oracle.
    ICurveGaugeControllerOracle public immutable curveGaugeControllerOracle;

    ////////////////////////////////////////////////////////////////
    /// --- STORAGE VARS
    ///////////////////////////////////////////////////////////////

    /// @notice Fee recipient address.
    address public feeRecipient;

    /// @notice Fee amount.
    uint256 public platformFee;

    /// @notice Governance address
    address public governance;

    /// @notice Bribe ID Counter.
    uint256 public nextID;

    /// @notice ID => Bribe.
    mapping(uint256 => Bribe) public bribes;

    /// @notice ID => Bribe In Queue to be upgraded.
    mapping(uint256 => Upgrade) public upgradeBribeQueue;

    /// @notice ID => Period running.
    mapping(uint256 => Period) public activePeriod;

    /// @notice BribeId => isUpgradeable. If true, the bribe can be upgraded.
    mapping(uint256 => bool) public isUpgradeable;

    /// @notice ID => Amount Claimed per Bribe.
    mapping(uint256 => uint256) public amountClaimed;

    /// @notice ID => Amount of reward per token distributed.
    mapping(uint256 => uint256) public rewardPerVote;

    /// @notice Blacklisted addresses per bribe that aren't counted for rewards arithmetics.
    mapping(uint256 => mapping(address => bool)) public isBlacklisted;

    /// @notice Last time a user claimed
    mapping(address => mapping(uint256 => uint256)) public lastUserClaim;

    /// @notice Whitelisted Address(Liquid Wrappers) to prevent claiming on their behalf if no recipient is set.
    mapping(address => bool) public whitelisted;

    ////////////////////////////////////////////////////////////////
    /// --- MODIFIERS
    ///////////////////////////////////////////////////////////////

    modifier onlyManager(uint256 _id) {
        if (msg.sender != bribes[_id].manager) revert AUTH_MANAGER_ONLY();
        _;
    }

    modifier notKilled() {
        if (isKilled) revert KILLED();
        _;
    }

    ////////////////////////////////////////////////////////////////
    /// --- EVENTS
    ///////////////////////////////////////////////////////////////

    /// @notice Emitted when a new bribe is created.
    event BribeCreated(
        uint256 indexed id,
        address indexed gauge,
        address manager,
        address indexed rewardToken,
        uint8 numberOfPeriods,
        uint256 maxRewardPerVote,
        uint256 rewardPerPeriod,
        uint256 totalRewardAmount,
        bool isUpgradeable
    );

    /// @notice Emitted when a bribe is closed.
    event BribeClosed(uint256 id, uint256 remainingReward);

    /// @notice Emitted when a bribe period is rolled over.
    event PeriodRolledOver(uint256 id, uint256 periodId, uint256 timestamp, uint256 rewardPerPeriod);

    /// @notice Emitted on claim.
    event Claimed(
        address indexed user,
        address indexed rewardToken,
        uint256 indexed bribeId,
        uint256 amount,
        uint256 protocolFees,
        uint256 period
    );

    /// @notice Emitted when a bribe is queued to upgrade.
    event BribeDurationIncreaseQueued(
        uint256 id, uint8 numberOfPeriods, uint256 totalRewardAmount, uint256 maxRewardPerVote
    );

    /// @notice Emitted when a bribe is upgraded.
    event BribeDurationIncreased(
        uint256 id, uint8 numberOfPeriods, uint256 totalRewardAmount, uint256 maxRewardPerVote
    );

    /// @notice Emitted when a bribe manager is updated.
    event ManagerUpdated(uint256 id, address indexed manager);

    ////////////////////////////////////////////////////////////////
    /// --- ERRORS
    ///////////////////////////////////////////////////////////////

    error KILLED();
    error WRONG_INPUT();
    error ZERO_ADDRESS();
    error NO_PERIODS_LEFT();
    error INVALID_GAUGE();
    error NOT_GOVERNANCE();
    error NOT_UPGRADEABLE();
    error USER_NOT_UPDATED();
    error ALREADY_INCREASED();
    error AUTH_MANAGER_ONLY();
    error NOT_ALLOWED_OPERATION();
    error INVALID_NUMBER_OF_PERIODS();
    error NO_RECEIVER_SET_FOR_WHITELISTED();

    ////////////////////////////////////////////////////////////////
    /// --- CONSTRUCTOR
    ///////////////////////////////////////////////////////////////

    /// @notice Create Bribe platform.
    /// @param _curveGaugeControllerOracle address of the curve gauge controller oracle.
    constructor(address _curveGaugeControllerOracle) {
        curveGaugeControllerOracle = ICurveGaugeControllerOracle(_curveGaugeControllerOracle);

        governance = msg.sender;
    }

    ////////////////////////////////////////////////////////////////
    /// --- BRIBE CREATION LOGIC
    ///////////////////////////////////////////////////////////////

    /// @notice Create a new bribe.
    /// @param gauge Address of the target gauge.
    /// @param rewardToken Address of the ERC20 used or rewards.
    /// @param numberOfPeriods Number of periods.
    /// @param maxRewardPerVote Target Bias for the Gauge.
    /// @param totalRewardAmount Total Reward Added.
    /// @param blacklist Array of addresses to blacklist.
    /// @return newBribeID of the bribe created.
    function createBribe(
        address gauge,
        address manager,
        address rewardToken,
        uint8 numberOfPeriods,
        uint256 maxRewardPerVote,
        uint256 totalRewardAmount,
        address[] calldata blacklist,
        bool upgradeable
    ) external nonReentrant notKilled returns (uint256 newBribeID) {
        if (rewardToken == address(0)) revert ZERO_ADDRESS();
        if (numberOfPeriods < MINIMUM_PERIOD) revert INVALID_NUMBER_OF_PERIODS();
        if (totalRewardAmount == 0 || maxRewardPerVote == 0) revert WRONG_INPUT();

        // Transfer the rewards to the contracts.
        SafeTransferLib.safeTransferFrom(rewardToken, msg.sender, address(this), totalRewardAmount);

        unchecked {
            // Get the ID for that new Bribe and increment the nextID counter.
            newBribeID = nextID;

            ++nextID;
        }

        uint256 rewardPerPeriod = totalRewardAmount.mulDiv(1, numberOfPeriods);
        uint256 currentPeriod = getCurrentPeriod();

        bribes[newBribeID] = Bribe({
            gauge: gauge,
            manager: manager,
            rewardToken: rewardToken,
            numberOfPeriods: numberOfPeriods,
            endTimestamp: currentPeriod + ((numberOfPeriods + 1) * _WEEK),
            maxRewardPerVote: maxRewardPerVote,
            totalRewardAmount: totalRewardAmount,
            blacklist: blacklist
        });

        emit BribeCreated(
            newBribeID,
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
        isUpgradeable[newBribeID] = upgradeable;
        // Starting from next period.
        activePeriod[newBribeID] = Period(0, currentPeriod + _WEEK, rewardPerPeriod);

        // Add the addresses to the blacklist.
        uint256 length = blacklist.length;
        for (uint256 i = 0; i < length;) {
            isBlacklisted[newBribeID][blacklist[i]] = true;
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Claim rewards for a given bribe.
    /// @param bribeId ID of the bribe.
    /// @return Amount of rewards claimed.
    function claim(uint256 bribeId, ProofData memory proofData) external returns (uint256) {
        return _claim(bribeId, proofData);
    }

    /// @notice Claim all rewards for multiple bribes.
    /// @param ids Array of bribe IDs to claim.
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

    /// @notice Claim rewards for a given bribe.
    /// @param bribeId ID of the bribe.
    /// @return amount of rewards claimed.
    function _claim(uint256 bribeId, ProofData memory proofData)
        internal
        nonReentrant
        notKilled
        returns (uint256 amount)
    {
        if (isBlacklisted[bribeId][proofData.user]) return 0;
        // Update if needed the current period.
        uint256 currentPeriod = _updateBribePeriod(bribeId, proofData);
        uint256 snapshotBlock = curveGaugeControllerOracle.last_eth_block_number();

        if (currentPeriod != curveGaugeControllerOracle.activePeriod()) return 0;

        Bribe storage bribe = bribes[bribeId];

        ICurveGaugeControllerOracle.VotedSlope memory userSlope;
        uint256 lastVote;

        if (curveGaugeControllerOracle.isUserUpdated(snapshotBlock, proofData.user, bribe.gauge)) {
            userSlope = curveGaugeControllerOracle.voteUserSlope(snapshotBlock, proofData.user, bribe.gauge);
            lastVote = curveGaugeControllerOracle.lastUserVote(snapshotBlock, proofData.user, bribe.gauge);
        } else {
            (, userSlope, lastVote,) = curveGaugeControllerOracle.extractProofState(
                proofData.user, bribe.gauge, proofData.headerRlp, proofData.userProofRlp
            );
        }

        // End timestamp of the bribe.
        uint256 endTimestamp = bribe.endTimestamp;

        if (
            userSlope.slope == 0 || lastUserClaim[proofData.user][bribeId] >= currentPeriod
                || currentPeriod >= userSlope.end || currentPeriod <= lastVote || currentPeriod >= endTimestamp
                || currentPeriod != getCurrentPeriod()
        ) return 0;

        // Update User last claim period.
        lastUserClaim[proofData.user][bribeId] = currentPeriod;

        // Voting Power = userSlope * dt
        // with dt = lock_end - period.
        uint256 _bias = _getAddrBias(userSlope.slope, userSlope.end, currentPeriod);
        // Compute the reward amount based on
        // Reward / Total Votes.
        amount = _bias.mulWad(rewardPerVote[bribeId]);
        // Compute the reward amount based on
        // the max price to pay.
        uint256 _amountWithMaxPrice = _bias.mulWad(bribe.maxRewardPerVote);
        // Distribute the _min between the amount based on votes, and price.
        amount = _min(amount, _amountWithMaxPrice);

        // Update the amount claimed.
        amountClaimed[bribeId] += amount;

        uint256 feeAmount;

        if (platformFee != 0) {
            feeAmount = amount.mulWad(platformFee);
            amount -= feeAmount;

            // Transfer fees.
            SafeTransferLib.safeTransfer(bribe.rewardToken, feeRecipient, feeAmount);
        }

        address receiver = curveGaugeControllerOracle.recipient(proofData.user);
        if (whitelisted[proofData.user] && receiver == address(0)) revert NO_RECEIVER_SET_FOR_WHITELISTED();
        receiver = receiver != address(0) ? receiver : proofData.user;

        //Transfer to user
        SafeTransferLib.safeTransfer(bribe.rewardToken, receiver, amount);

        emit Claimed(proofData.user, bribe.rewardToken, bribeId, amount, feeAmount, currentPeriod);
    }

    /// @notice Update the current period for a given bribe.
    /// @param bribeId Bribe ID.
    /// @return current/updated period.
    function _updateBribePeriod(uint256 bribeId, ProofData memory proofData) internal returns (uint256) {
        Period storage _activePeriod = activePeriod[bribeId];

        uint256 currentPeriod = getCurrentPeriod();

        if (_activePeriod.id == 0 && currentPeriod == _activePeriod.timestamp) {
            // Check if there is an upgrade in queue and update the bribe.
            _checkForUpgrade(bribeId);

            // Initialize reward per token.
            // Only for the first period, and if not already initialized.
            _updateRewardPerToken(bribeId, proofData, currentPeriod);
        }

        // Increase Period
        if (block.timestamp >= _activePeriod.timestamp + _WEEK) {
            // Check if there is an upgrade in queue and update the bribe.
            _checkForUpgrade(bribeId);

            // Checkpoint gauge to have up to date gauge weight.
            // Roll to next period.
            _rollOverToNextPeriod(bribeId, currentPeriod, proofData);

            return currentPeriod;
        }

        return _activePeriod.timestamp;
    }

    /// @notice Checks for an upgrade and update the bribe.
    function _checkForUpgrade(uint256 bribeId) internal {
        Upgrade storage upgradedBribe = upgradeBribeQueue[bribeId];

        // Check if there is an upgrade in queue.
        if (upgradedBribe.totalRewardAmount != 0) {
            // Save new values.
            bribes[bribeId].numberOfPeriods = upgradedBribe.numberOfPeriods;
            bribes[bribeId].totalRewardAmount = upgradedBribe.totalRewardAmount;
            bribes[bribeId].maxRewardPerVote = upgradedBribe.maxRewardPerVote;
            bribes[bribeId].endTimestamp = upgradedBribe.endTimestamp;

            if (upgradedBribe.blacklist.length > 0) {
                bribes[bribeId].blacklist = upgradedBribe.blacklist;
            }

            emit BribeDurationIncreased(
                bribeId, upgradedBribe.numberOfPeriods, upgradedBribe.totalRewardAmount, upgradedBribe.maxRewardPerVote
            );

            // Reset the next values.
            delete upgradeBribeQueue[bribeId];
        }
    }

    /// @notice Roll over to next period.
    /// @param bribeId Bribe ID.
    /// @param currentPeriod Next period timestamp.
    function _rollOverToNextPeriod(uint256 bribeId, uint256 currentPeriod, ProofData memory proofData) internal {
        uint8 index = getActivePeriodPerBribe(bribeId);

        Bribe storage bribe = bribes[bribeId];

        uint256 rewardPerPeriod;

        uint256 periodsLeft = getPeriodsLeft(bribeId);
        rewardPerPeriod = bribe.totalRewardAmount - amountClaimed[bribeId];

        if (bribe.endTimestamp > currentPeriod + _WEEK && periodsLeft > 1) {
            rewardPerPeriod = rewardPerPeriod.mulDiv(1, periodsLeft);
        }

        // Get adjusted slope without blacklisted addresses.
        uint256 gaugeBias = _getAdjustedBias(bribe.gauge, bribe.blacklist, currentPeriod, proofData);

        rewardPerVote[bribeId] = rewardPerPeriod.mulDiv(_BASE_UNIT, gaugeBias);
        activePeriod[bribeId] = Period(index, currentPeriod, rewardPerPeriod);

        emit PeriodRolledOver(bribeId, index, currentPeriod, rewardPerPeriod);
    }

    /// @notice Update the amount of reward per token for a given bribe.
    /// @dev This function is only called once per Bribe.
    function _updateRewardPerToken(uint256 bribeId, ProofData memory proofData, uint256 currentPeriod) internal {
        if (rewardPerVote[bribeId] == 0) {
            uint256 gaugeBias =
                _getAdjustedBias(bribes[bribeId].gauge, bribes[bribeId].blacklist, currentPeriod, proofData);
            rewardPerVote[bribeId] = activePeriod[bribeId].rewardPerPeriod.mulDiv(_BASE_UNIT, gaugeBias);
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
        uint256 snapshotBlock = curveGaugeControllerOracle.last_eth_block_number();
        // Cache the user slope.
        ICurveGaugeControllerOracle.VotedSlope memory userSlope;
        // Bias
        uint256 _bias;
        // Cache the length of the array.
        uint256 length = _addressesBlacklisted.length;
        // Get the gauge slope.
        gaugeBias = curveGaugeControllerOracle.pointWeights(gauge, snapshotBlock).bias;

        if (gaugeBias == 0) {
            curveGaugeControllerOracle.submit_state(proofData.user, gauge, proofData.headerRlp, proofData.userProofRlp);

            if (!curveGaugeControllerOracle.isUserUpdated(snapshotBlock, proofData.user, gauge)) {
                revert USER_NOT_UPDATED();
            }

            gaugeBias = curveGaugeControllerOracle.pointWeights(gauge, snapshotBlock).bias;
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
    }

    ////////////////////////////////////////////////////////////////
    /// --- MANAGEMENT LOGIC
    ///////////////////////////////////////////////////////////////

    /// @notice Increase Bribe duration.
    /// @param _bribeId ID of the bribe.
    /// @param _additionnalPeriods Number of periods to add.
    /// @param _increasedAmount Total reward amount to add.
    /// @param _newMaxPricePerVote Total reward amount to add.
    function increaseBribeDuration(
        uint256 _bribeId,
        uint8 _additionnalPeriods,
        uint256 _increasedAmount,
        uint256 _newMaxPricePerVote,
        address[] calldata _addressesBlacklisted
    ) external nonReentrant notKilled onlyManager(_bribeId) {
        if (!isUpgradeable[_bribeId]) revert NOT_UPGRADEABLE();
        if (getPeriodsLeft(_bribeId) < 1) revert NO_PERIODS_LEFT();
        if (_increasedAmount == 0 || _newMaxPricePerVote == 0) {
            revert WRONG_INPUT();
        }

        Bribe storage bribe = bribes[_bribeId];
        Upgrade memory upgradedBribe = upgradeBribeQueue[_bribeId];

        SafeTransferLib.safeTransferFrom(bribe.rewardToken, msg.sender, address(this), _increasedAmount);

        if (upgradedBribe.totalRewardAmount != 0) {
            upgradedBribe = Upgrade({
                numberOfPeriods: upgradedBribe.numberOfPeriods + _additionnalPeriods,
                totalRewardAmount: upgradedBribe.totalRewardAmount + _increasedAmount,
                maxRewardPerVote: _newMaxPricePerVote,
                endTimestamp: upgradedBribe.endTimestamp + (_additionnalPeriods * _WEEK),
                blacklist: _addressesBlacklisted
            });
        } else {
            upgradedBribe = Upgrade({
                numberOfPeriods: bribe.numberOfPeriods + _additionnalPeriods,
                totalRewardAmount: bribe.totalRewardAmount + _increasedAmount,
                maxRewardPerVote: _newMaxPricePerVote,
                endTimestamp: bribe.endTimestamp + (_additionnalPeriods * _WEEK),
                blacklist: _addressesBlacklisted
            });
        }

        upgradeBribeQueue[_bribeId] = upgradedBribe;

        emit BribeDurationIncreaseQueued(
            _bribeId, upgradedBribe.numberOfPeriods, upgradedBribe.totalRewardAmount, _newMaxPricePerVote
        );
    }

    /// @notice Close Bribe if there is remaining.
    /// @param bribeId ID of the bribe to close.
    function closeBribe(uint256 bribeId) external nonReentrant onlyManager(bribeId) {
        // Check if the currentPeriod is the last one.
        // If not, we can increase the duration.
        Bribe storage bribe = bribes[bribeId];

        if (getCurrentPeriod() >= bribe.endTimestamp || isKilled) {
            uint256 leftOver;
            Upgrade memory upgradedBribe = upgradeBribeQueue[bribeId];
            if (upgradedBribe.totalRewardAmount != 0) {
                leftOver = upgradedBribe.totalRewardAmount - amountClaimed[bribeId];
                delete upgradeBribeQueue[bribeId];
            } else {
                leftOver = bribes[bribeId].totalRewardAmount - amountClaimed[bribeId];
            }
            // Transfer the left over to the owner.
            SafeTransferLib.safeTransfer(bribe.rewardToken, bribe.manager, leftOver);
            delete bribes[bribeId].manager;

            emit BribeClosed(bribeId, leftOver);
        }
    }

    /// @notice Update Bribe Manager.
    /// @param bribeId ID of the bribe.
    /// @param newManager Address of the new manager.
    function updateManager(uint256 bribeId, address newManager) external nonReentrant onlyManager(bribeId) {
        emit ManagerUpdated(bribeId, bribes[bribeId].manager = newManager);
    }

    function kill() external {
        if (msg.sender != governance) revert NOT_GOVERNANCE();
        isKilled = true;
    }

    function setGovernance(address _governance) external {
        if (msg.sender != governance) revert NOT_GOVERNANCE();
        governance = _governance;
    }

    function setPlatformFee(uint256 _platformFee) external {
        if (msg.sender != governance) revert NOT_GOVERNANCE();
        platformFee = _platformFee;
    }

    function setFeeRecipient(address _feeRecipient) external {
        if (msg.sender != governance) revert NOT_GOVERNANCE();
        feeRecipient = _feeRecipient;
    }

    function whitelistAddress(address _address, bool _isWhitelist) external {
        if (msg.sender != governance) revert NOT_GOVERNANCE();
        whitelisted[_address] = _isWhitelist;
    }

    ////////////////////////////////////////////////////////////////
    /// --- UTILS FUNCTIONS
    ///////////////////////////////////////////////////////////////

    function _submitState(
        address _user,
        address _gauge,
        bytes memory _headerRlp,
        bytes memory _proofRlp,
        uint256 snapshotBlock
    ) internal returns (ICurveGaugeControllerOracle.VotedSlope memory slope) {
        if (!curveGaugeControllerOracle.isUserUpdated(snapshotBlock, _user, _gauge)) {
            curveGaugeControllerOracle.submit_state(_user, _gauge, _headerRlp, _proofRlp);
            if (!curveGaugeControllerOracle.isUserUpdated(snapshotBlock, _user, _gauge)) {
                revert USER_NOT_UPDATED();
            }
        }

        slope = curveGaugeControllerOracle.voteUserSlope(snapshotBlock, _user, _gauge);
    }

    /// @notice Returns the number of periods left for a given bribe.
    /// @param bribeId ID of the bribe.
    function getPeriodsLeft(uint256 bribeId) public view returns (uint256 periodsLeft) {
        Bribe memory bribe = bribes[bribeId];
        uint256 endTimestamp = bribe.endTimestamp;

        periodsLeft = endTimestamp > getCurrentPeriod() ? (endTimestamp - getCurrentPeriod()) / _WEEK : 0;
    }

    /// @notice Return the bribe object for a given ID.
    /// @param bribeId ID of the bribe.
    function getBribe(uint256 bribeId) external view returns (Bribe memory) {
        return bribes[bribeId];
    }

    /// @notice Return the bribe in queue for a given ID.
    /// @dev Can return an empty bribe if there is no upgrade.
    /// @param bribeId ID of the bribe.
    function getUpgradedBribeQueued(uint256 bribeId) external view returns (Upgrade memory) {
        return upgradeBribeQueue[bribeId];
    }

    /// @notice Return the blacklisted addresses of a bribe for a given ID.
    /// @param bribeId ID of the bribe.
    function getBlacklistedAddressesForBribe(uint256 bribeId) external view returns (address[] memory) {
        return bribes[bribeId].blacklist;
    }

    /// @notice Return the active period running of bribe given an ID.
    /// @param bribeId ID of the bribe.
    function getActivePeriod(uint256 bribeId) public view returns (Period memory) {
        return activePeriod[bribeId];
    }

    /// @notice Return the expected current period id.
    /// @param bribeId ID of the bribe.
    function getActivePeriodPerBribe(uint256 bribeId) public view returns (uint8) {
        Bribe memory bribe = bribes[bribeId];

        uint256 endTimestamp = bribe.endTimestamp;
        uint256 numberOfPeriods = bribe.numberOfPeriods;
        uint256 periodsLeft = endTimestamp > getCurrentPeriod() ? (endTimestamp - getCurrentPeriod()) / _WEEK : 0;

        // If periodsLeft is superior, then the bribe didn't start yet.
        return uint8(periodsLeft > numberOfPeriods ? 0 : numberOfPeriods - periodsLeft);
    }

    /// @notice Return the current period based on Gauge Controller rounding.
    function getCurrentPeriod() public view returns (uint256) {
        return (block.timestamp / _WEEK) * _WEEK;
    }

    /// @notice Return the minimum between two numbers.
    /// @param a First number.
    /// @param b Second number.
    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function _getAddrBias(uint256 userSlope, uint256 endLockTime, uint256 currentPeriod)
        internal
        pure
        returns (uint256)
    {
        if (currentPeriod + _WEEK >= endLockTime) return 0;
        return userSlope * (endLockTime - currentPeriod);
    }
}
