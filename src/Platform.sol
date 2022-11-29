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

import { ReentrancyGuard } from "solmate/utils/ReentrancyGuard.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { ERC20, SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

import { ICurveGaugeControllerOracle } from "src/interfaces/ICurveGaugeControllerOracle.sol";

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
    }

    struct ProofData {
        bytes headerRlp;
        bytes[] proofRlp;
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

    /// @notice snapshot block number
    uint256 public snapshotBlock;

    /// @notice Fee recipient address.
    address public feeRecipient;

    /// @notice Fee amount.
    uint256 public platformFee;

    ////////////////////////////////////////////////////////////////
    /// --- STORAGE VARS
    ///////////////////////////////////////////////////////////////

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
    mapping(uint256 => uint256) public rewardPerToken;

    /// @notice Blacklisted addresses per bribe that aren't counted for rewards arithmetics.
    mapping(uint256 => mapping(address => bool)) public isBlacklisted;

    /// @notice Last time a user claimed
    mapping(address => mapping(uint256 => uint256)) public lastUserClaim;

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
        uint256 period
    );

    /// @notice Emitted when a bribe is queued to upgrade.
    event BribeDurationIncreaseQueued(
        uint256 id,
        uint8 numberOfPeriods,
        uint256 totalRewardAmount,
        uint256 maxRewardPerVote
    );

    /// @notice Emitted when a bribe is upgraded.
    event BribeDurationIncreased(
        uint256 id,
        uint8 numberOfPeriods,
        uint256 totalRewardAmount,
        uint256 maxRewardPerVote
    );

    /// @notice Emitted when a bribe manager is updated.
    event ManagerUpdated(uint256 id, address indexed manager);

    ////////////////////////////////////////////////////////////////
    /// --- ERRORS
    ///////////////////////////////////////////////////////////////

    error KILLED();
    error WRONG_INPUT();
    error ZERO_ADDRESS();
    error INVALID_GAUGE();
    error NOT_UPGRADEABLE();
    error AUTH_MANAGER_ONLY();
    error ALREADY_INCREASED();
    error NOT_ALLOWED_OPERATION();
    error INVALID_NUMBER_OF_PERIODS();
    error USER_NOT_UPDATED();

    ////////////////////////////////////////////////////////////////
    /// --- CONSTRUCTOR
    ///////////////////////////////////////////////////////////////

    /// @notice Create Bribe platform.
    /// @param _curveGaugeControllerOracle address of the curve gauge controller oracle.
    constructor(address _curveGaugeControllerOracle) {
        curveGaugeControllerOracle = ICurveGaugeControllerOracle(_curveGaugeControllerOracle);
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
        if (totalRewardAmount == 0) revert WRONG_INPUT();

        // Transfer the rewards to the contracts.
        ERC20(rewardToken).safeTransferFrom(msg.sender, address(this), totalRewardAmount);

        unchecked {
            // Get the ID for that new Bribe and increment the nextID counter.
            newBribeID = nextID;

            ++nextID;
        }

        uint256 rewardPerPeriod = totalRewardAmount.mulDivDown(1, numberOfPeriods);

        bribes[newBribeID] = Bribe({
            gauge: gauge,
            manager: manager,
            rewardToken: rewardToken,
            numberOfPeriods: numberOfPeriods,
            endTimestamp: getCurrentPeriod() + ((numberOfPeriods + 1) * _WEEK),
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
            rewardPerPeriod,
            maxRewardPerVote,
            totalRewardAmount,
            upgradeable
        );

        // Set Upgradeable status.
        isUpgradeable[newBribeID] = upgradeable;
        // Starting from next period.
        activePeriod[newBribeID] = Period(0, getCurrentPeriod() + _WEEK, rewardPerPeriod);

        // Add the addresses to the blacklist.
        uint256 length = blacklist.length;
        for (uint256 i = 0; i < length; ) {
            isBlacklisted[newBribeID][blacklist[i]] = true;
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Claim rewards for a given bribe.
    /// @param bribeId ID of the bribe.
    /// @return Amount of rewards claimed.
    function claim(
        uint256 bribeId,
        bytes memory _block_header_rlp,
        bytes[] memory _proof_rlp
    ) external returns (uint256) {
        return _claim(msg.sender, bribeId, _block_header_rlp, _proof_rlp);
    }

    /// @notice Update Bribe for a given id.
    /// @param bribeId ID of the bribe.
    function updateBribePeriod(
        uint256 bribeId,
        bytes memory _block_header_rlp,
        bytes[] memory _proof_rlp
    ) external nonReentrant {
        _updateBribePeriod(bribeId, _block_header_rlp, _proof_rlp);
    }

    /// @notice Update multiple bribes for given ids.
    /// @param ids Array of Bribe IDs.
    function updateBribePeriods(uint256[] calldata ids, ProofData[] calldata proofs) external nonReentrant {
        uint256 length = ids.length;
        for (uint256 i = 0; i < length; ) {
            _updateBribePeriod(ids[i], proofs[i].headerRlp, proofs[i].proofRlp);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Claim all rewards for multiple bribes.
    /// @param ids Array of bribe IDs to claim.
    function claimAll(
        address recipient,
        uint256[] calldata ids,
        ProofData[] calldata proofs
    ) external {
        uint256 length = ids.length;

        for (uint256 i = 0; i < length; ) {
            uint256 id = ids[i];
            _claim(recipient, id, proofs[i].headerRlp, proofs[i].proofRlp);

            unchecked {
                ++i;
            }
        }
    }

    ////////////////////////////////////////////////////////////////
    /// --- INTERNAL LOGIC
    ///////////////////////////////////////////////////////////////

    /// @notice Claim rewards for a given bribe.
    /// @param user Address of the user.
    /// @param bribeId ID of the bribe.
    /// @return amount of rewards claimed.
    function _claim(
        address user,
        uint256 bribeId,
        bytes memory _block_header_rlp,
        bytes[] memory _proof_rlp
    ) internal nonReentrant notKilled returns (uint256 amount) {
        if (isBlacklisted[bribeId][user]) return 0;
        // Update if needed the current period.
        uint256 currentPeriod = _updateBribePeriod(bribeId, _block_header_rlp, _proof_rlp);

        Bribe storage bribe = bribes[bribeId];

        // Address of the target gauge.
        address gauge = bribe.gauge;
        // End timestamp of the bribe.
        uint256 endTimestamp = bribe.endTimestamp;
        if (!curveGaugeControllerOracle.userUpdated(snapshotBlock, user, gauge)) revert USER_NOT_UPDATED();
        // Get the last_vote timestamp.
        uint256 lastVote = curveGaugeControllerOracle.lastUserVote(snapshotBlock, user, gauge);

        ICurveGaugeControllerOracle.VotedSlope memory votedSlope = curveGaugeControllerOracle.voteUserSlopes(
            snapshotBlock,
            user,
            gauge
        );

        if (
            votedSlope.slope == 0 ||
            lastUserClaim[user][bribeId] >= currentPeriod ||
            currentPeriod >= votedSlope.end ||
            currentPeriod <= lastVote ||
            currentPeriod >= endTimestamp ||
            currentPeriod != getCurrentPeriod()
        ) return 0;

        // Update User last claim period.
        lastUserClaim[user][bribeId] = currentPeriod;

        // Voting Power = userSlope * dt
        // with dt = lock_end - period.
        uint256 _bias = _getAddrBias(votedSlope.slope, votedSlope.end, currentPeriod);
        // Compute the reward amount based on
        // Reward / Total Votes.
        amount = _bias.mulWadDown(rewardPerToken[bribeId]);
        // Compute the reward amount based on
        // the max price to pay.
        uint256 _amountWithMaxPrice = _bias.mulWadDown(bribe.maxRewardPerVote);
        // Distribute the _min between the amount based on votes, and price.
        amount = _min(amount, _amountWithMaxPrice);

        // Update the amount claimed.
        amountClaimed[bribeId] += amount;

        uint256 feeAmount;

        if (platformFee != 0) {
            feeAmount = amount.mulWadDown(platformFee);
            amount -= feeAmount;

            // Transfer fees.
            ERC20(bribe.rewardToken).safeTransfer(feeRecipient, feeAmount);
        }
        //Transfer to user
        ERC20(bribe.rewardToken).safeTransfer(user, amount);

        emit Claimed(user, bribe.rewardToken, bribeId, amount, currentPeriod);
    }

    /// @notice Update the current period for a given bribe.
    /// @param bribeId Bribe ID.
    /// @return current/updated period.
    function _updateBribePeriod(
        uint256 bribeId,
        bytes memory _block_header_rlp,
        bytes[] memory _proof_rlp
    ) internal returns (uint256) {
        Period storage _activePeriod = activePeriod[bribeId];

        uint256 currentPeriod = getCurrentPeriod();

        if (_activePeriod.id == 0 && currentPeriod == _activePeriod.timestamp) {
            // Initialize reward per token.
            // Only for the first period, and if not already initialized.
            _updateRewardPerToken(bribeId, _block_header_rlp, _proof_rlp);
        }

        // Increase Period
        if (block.timestamp >= _activePeriod.timestamp + _WEEK) {
            // Checkpoint gauge to have up to date gauge weight.
            // #TODO: add checkpoint for gauge.
            // gaugeController.checkpoint_gauge(bribes[bribeId].gauge);
            // Roll to next period.
            _rollOverToNextPeriod(bribeId, currentPeriod, _block_header_rlp, _proof_rlp);

            return currentPeriod;
        }

        return _activePeriod.timestamp;
    }

    /// @notice Roll over to next period.
    /// @param bribeId Bribe ID.
    /// @param currentPeriod Next period timestamp.
    function _rollOverToNextPeriod(
        uint256 bribeId,
        uint256 currentPeriod,
        bytes memory _block_header_rlp,
        bytes[] memory _proof_rlp
    ) internal {
        uint8 index = getActivePeriodPerBribe(bribeId);

        Upgrade storage upgradedBribe = upgradeBribeQueue[bribeId];

        // Check if there is an upgrade in queue.
        if (upgradedBribe.numberOfPeriods != 0) {
            // Save new values.
            bribes[bribeId].numberOfPeriods = upgradedBribe.numberOfPeriods;
            bribes[bribeId].totalRewardAmount = upgradedBribe.totalRewardAmount;
            bribes[bribeId].maxRewardPerVote = upgradedBribe.maxRewardPerVote;
            bribes[bribeId].endTimestamp = upgradedBribe.endTimestamp;

            emit BribeDurationIncreased(
                bribeId,
                upgradedBribe.numberOfPeriods,
                upgradedBribe.totalRewardAmount,
                upgradedBribe.maxRewardPerVote
            );

            // Reset the next values.
            delete upgradeBribeQueue[bribeId];
        }

        Bribe storage bribe = bribes[bribeId];

        uint256 rewardPerPeriod;

        uint256 periodsLeft = getPeriodsLeft(bribeId);
        rewardPerPeriod = bribe.totalRewardAmount - amountClaimed[bribeId];

        if (bribe.endTimestamp > currentPeriod + _WEEK && periodsLeft > 1) {
            rewardPerPeriod = rewardPerPeriod.mulDivDown(1, periodsLeft);
        }

        // Get adjusted slope without blacklisted addresses.
        uint256 gaugeBias = _getAdjustedBias(
            bribe.gauge,
            bribe.blacklist,
            currentPeriod,
            _block_header_rlp,
            _proof_rlp
        );

        rewardPerToken[bribeId] = rewardPerPeriod.mulDivDown(_BASE_UNIT, gaugeBias);
        activePeriod[bribeId] = Period(index, currentPeriod, rewardPerPeriod);

        emit PeriodRolledOver(bribeId, index, currentPeriod, rewardPerPeriod);
    }

    /// @notice Update the amount of reward per token for a given bribe.
    /// @dev This function is only called once per Bribe.
    function _updateRewardPerToken(
        uint256 bribeId,
        bytes memory _block_header_rlp,
        bytes[] memory _proof_rlp
    ) internal {
        if (rewardPerToken[bribeId] == 0) {
            uint256 currentPeriod = getCurrentPeriod();
            uint256 gaugeBias = _getAdjustedBias(
                bribes[bribeId].gauge,
                bribes[bribeId].blacklist,
                currentPeriod,
                _block_header_rlp,
                _proof_rlp
            );
            if (gaugeBias != 0) {
                rewardPerToken[bribeId] = activePeriod[bribeId].rewardPerPeriod.mulDivDown(_BASE_UNIT, gaugeBias);
            }
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
        bytes memory _block_header_rlp,
        bytes[] memory _proof_rlp
    ) internal returns (uint256 gaugeBias) {
        require(_proof_rlp.length == _addressesBlacklisted.length + 1, "Invalid proof  length");
        // Cache the user slope.
        ICurveGaugeControllerOracle.VotedSlope memory userSlope;
        // Bias
        uint256 _bias;
        // Cache the length of the array.
        uint256 length = _addressesBlacklisted.length;
        // Get the gauge slope.
        gaugeBias = curveGaugeControllerOracle.pointWeights(gauge, snapshotBlock).bias;

        unchecked {
            for (uint256 i = 0; i < length; ) {
                if (!curveGaugeControllerOracle.userUpdated(snapshotBlock, _addressesBlacklisted[i], gauge)) {
                    curveGaugeControllerOracle.submit_state(
                        _addressesBlacklisted[i],
                        gauge,
                        _block_header_rlp,
                        _proof_rlp[i + 1] // first element is the particular user that claims the bribes
                    );
                }
                if (!curveGaugeControllerOracle.userUpdated(snapshotBlock, _addressesBlacklisted[i], gauge))
                    revert USER_NOT_UPDATED();

                // Get the user slope.
                userSlope = curveGaugeControllerOracle.voteUserSlopes(snapshotBlock, _addressesBlacklisted[i], gauge);
                // Remove the user bias from the gauge bias.
                _bias = _getAddrBias(userSlope.slope, userSlope.end, period);

                gaugeBias -= _bias;
                // Increment i.
                ++i;
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
        uint256 _newMaxPricePerVote
    ) external nonReentrant notKilled onlyManager(_bribeId) {
        if (!isUpgradeable[_bribeId]) revert NOT_UPGRADEABLE();
        if (getPeriodsLeft(_bribeId) < 2) revert NOT_ALLOWED_OPERATION();

        Upgrade memory upgradedBribe = upgradeBribeQueue[_bribeId];
        if (upgradedBribe.numberOfPeriods != 0) revert ALREADY_INCREASED();
        if (_additionnalPeriods == 0 || _increasedAmount == 0) revert WRONG_INPUT();

        Bribe storage bribe = bribes[_bribeId];
        ERC20(bribe.rewardToken).safeTransferFrom(msg.sender, address(this), _increasedAmount);

        upgradedBribe = Upgrade({
            numberOfPeriods: bribe.numberOfPeriods + _additionnalPeriods,
            totalRewardAmount: bribe.totalRewardAmount + _increasedAmount,
            maxRewardPerVote: _newMaxPricePerVote,
            endTimestamp: bribe.endTimestamp + (_additionnalPeriods * _WEEK)
        });

        upgradeBribeQueue[_bribeId] = upgradedBribe;

        emit BribeDurationIncreaseQueued(
            _bribeId,
            upgradedBribe.numberOfPeriods,
            upgradedBribe.totalRewardAmount,
            _newMaxPricePerVote
        );
    }

    /// @notice Close Bribe if there is remaining.
    /// @param bribeId ID of the bribe to close.
    function closeBribe(uint256 bribeId) external nonReentrant onlyManager(bribeId) {
        // Check if the currentPeriod is the last one.
        // If not, we can increase the duration.
        Bribe storage bribe = bribes[bribeId];

        if (getCurrentPeriod() >= bribe.endTimestamp || isKilled) {
            uint256 leftOver = bribes[bribeId].totalRewardAmount - amountClaimed[bribeId];
            // Transfer the left over to the owner.
            ERC20(bribe.rewardToken).safeTransfer(bribe.manager, leftOver);
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
        //TODO: add autharization beside factory
        // if (msg.sender != address(factory)) revert NOT_ALLOWED_OPERATION();
        isKilled = true;
    }

    ////////////////////////////////////////////////////////////////
    /// --- UTILS FUNCTIONS
    ///////////////////////////////////////////////////////////////

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

    function _getAddrBias(
        uint256 userSlope,
        uint256 endLockTime,
        uint256 currentPeriod
    ) internal pure returns (uint256) {
        if (currentPeriod + _WEEK >= endLockTime) return 0;
        return userSlope * (endLockTime - currentPeriod);
    }
}
