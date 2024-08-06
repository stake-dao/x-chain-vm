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
import {IGaugeVoting} from "src/interfaces/IGaugeVoting.sol";
import {IPlatformNoProof} from "src/interfaces/IPlatformNoProof.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

/// @title PancakeSwap Platform
/// @author Stake DAO
/// @notice VoteMarket for PancakeSwap gauges. Takes into account the 2 weeks voting Epoch, so claimable period active on EVEN week Thursday.
/// @dev Forked from Platform contract
contract PlatformNoProof is Owned, ReentrancyGuard, IPlatformNoProof {
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

    /// @notice ClaimData struct
    // struct ClaimData {
    //     address user;
    //     uint256 lastVote;
    //     uint256 gaugeBias;
    //     uint256 gaugeSlope;
    //     uint256 userVoteSlope;
    //     uint256 userVotePower;
    //     uint256 userVoteEnd;
    // }

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
    //IGaugeVoting public immutable gaugeController;

    /// @notice Voting Escrow.
    //IVotingEscrow public immutable escrow;

    ////////////////////////////////////////////////////////////////
    /// --- STORAGE VARS
    ///////////////////////////////////////////////////////////////

    /// @notice Fee.
    uint256 public fee;

    /// @notice Bounty ID Counter.
    uint256 public nextID;

    /// @notice Fee collector.
    address public feeCollector;

    /// @notice Bounty claimer
    address public claimer;

    /// @notice ID => Bounty.
    mapping(uint256 => Bounty) public bounties;

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

    ////////////////////////////////////////////////////////////////
    /// --- MODIFIERS
    ///////////////////////////////////////////////////////////////

    modifier notKilled() {
        if (isKilled) revert KILLED();
        _;
    }

    modifier onlyClaimer() {
        if (msg.sender != claimer) revert AUTH_CLAIMER_ONLY();
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

    /// @notice Emitted when fees are collected.
    /// @param rewardToken Reward token address.
    /// @param amount Amount collected.
    event FeesCollected(address indexed rewardToken, uint256 amount);

    /// @notice Emitted when bounty claimer is updated.
    /// @param claimer Address of the claimer.
    event ClaimerSet(address claimer);

    ////////////////////////////////////////////////////////////////
    /// --- ERRORS
    ///////////////////////////////////////////////////////////////

    error KILLED();
    error WRONG_INPUT();
    error ZERO_ADDRESS();
    error INVALID_TOKEN();
    error ALREADY_CLOSED();
    error NO_PERIODS_LEFT();
    error NOT_UPGRADEABLE();
    error AUTH_CLAIMER_ONLY();
    error AUTH_MANAGER_ONLY();
    error INVALID_NUMBER_OF_EPOCHS();

    ////////////////////////////////////////////////////////////////
    /// --- CONSTRUCTOR
    ///////////////////////////////////////////////////////////////

    /// @notice Create Bounty platform.
    /// @param _feeCollector Fee collector
    /// @param _owner Owner
    constructor(address _feeCollector, address _owner, address _claimer) Owned(_owner) {
        fee = _DEFAULT_FEE;
        feeCollector = _feeCollector;
        claimer = _claimer;
        //gaugeController = IGaugeVoting(_gaugeController);
        //escrow = IVotingEscrow(gaugeController.votingEscrow());
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
            isBlacklisted[newBountyId][blacklist[i]] = true;
            unchecked {
                ++i;
            }
        }
    }

    function claim(uint256 _bountyId, address _recipient, ClaimData memory _claimData) external {
        ClaimData memory emptyClaimData;
        _claim(_bountyId, _claimData, emptyClaimData, _recipient);
    }

    function claimWithProxy(
        uint256 _bountyId,
        address _recipient,
        ClaimData memory _userClaimData,
        ClaimData memory _proxyClaimData
    ) external {
        _claim(_bountyId, _userClaimData, _proxyClaimData, _recipient);
    }

    /// @notice Claim rewards for a given bounty.
    /// @param bountyId ID of the bounty.
    /// @return Amount of rewards claimed.
    // function claim(uint256 bountyId) external returns (uint256) {
    //     return _claim(msg.sender, msg.sender, bountyId);
    // }

    /// @notice Claim rewards for a given bounty.
    /// @param bountyId ID of the bounty.
    /// @return Amount of rewards claimed.
    // function claim(uint256 bountyId, address _recipient) external returns (uint256) {
    //     return _claim(msg.sender, _recipient, bountyId);
    // }

    /// @notice Claim rewards for a given bounty.
    /// @param user User to claim for.
    /// @param bountyId ID of the bounty.
    /// @return Amount of rewards claimed.
    // function claimFor(address user, uint256 bountyId) external returns (uint256) {
    //     address _recipient = recipient[user];

    //     return _claim(user, _recipient != address(0) ? _recipient : user, bountyId);
    // }

    /// @notice Claim all rewards for multiple bounties.
    /// @param ids Array of bounty IDs to claim.
    // function claimAll(uint256[] calldata ids) external {
    //     uint256 length = ids.length;

    //     for (uint256 i = 0; i < length;) {
    //         uint256 id = ids[i];

    //         _claim(msg.sender, msg.sender, id);

    //         unchecked {
    //             ++i;
    //         }
    //     }
    // }

    /// @notice Claim all rewards for multiple bounties to a given recipient.
    /// @param ids Array of bounty IDs to claim.
    /// @param _recipient Address to send the rewards to.
    // function claimAll(uint256[] calldata ids, address _recipient) external {
    //     uint256 length = ids.length;

    //     for (uint256 i = 0; i < length;) {
    //         uint256 id = ids[i];
    //         _claim(msg.sender, _recipient, id);

    //         unchecked {
    //             ++i;
    //         }
    //     }
    // }

    /// @notice Claim all rewards for multiple bounties on behalf of a user.
    /// @param ids Array of bounty IDs to claim.
    /// @param _user Address to claim the rewards for.
    // function claimAllFor(address _user, uint256[] calldata ids) external {
    //     address _recipient = recipient[_user];
    //     if (_recipient == address(0)) _recipient = _user;

    //     uint256 length = ids.length;
    //     for (uint256 i = 0; i < length;) {
    //         uint256 id = ids[i];
    //         _claim(_user, _recipient, id);
    //         unchecked {
    //             ++i;
    //         }
    //     }
    // }

    /// @notice Update Bounty for a given id.
    /// @param bountyId ID of the bounty.
    // function updateBountyPeriod(uint256 bountyId) external {
    //     _updateBountyPeriod(bountyId);
    // }

    /// @notice Update multiple bounties for given ids.
    /// @param ids Array of Bounty IDs.
    // function updateBountyPeriods(uint256[] calldata ids) external {
    //     uint256 length = ids.length;
    //     for (uint256 i = 0; i < length;) {
    //         _updateBountyPeriod(ids[i]);
    //         unchecked {
    //             ++i;
    //         }
    //     }
    // }

    /// @notice Set a recipient address for calling user.
    /// @param _recipient Address of the recipient.
    /// @dev Recipient are used when calling claimFor functions. Regular functions will use msg.sender as recipient,
    ///  or recipient parameter provided if called by msg.sender.
    function setRecipient(address _recipient) external {
        recipient[msg.sender] = _recipient;

        emit RecipientSet(msg.sender, _recipient);
    }

    ////////////////////////////////////////////////////////////////
    /// --- INTERNAL LOGIC
    ///////////////////////////////////////////////////////////////

    /// @notice Claim rewards for a given bounty.
    /// @param _bountyId ID of the bounty.
    /// @param _userClaimData ClaimData of the voter.
    /// @param _proxyClaimData ClaimData of the proxy.
    /// @param _recipient Address of the recipient.

    /// @return amount of rewards claimed.
    function _claim(
        uint256 _bountyId,
        ClaimData memory _userClaimData,
        ClaimData memory _proxyClaimData,
        address _recipient
    ) internal notKilled onlyClaimer returns (uint256 amount) {
        // Update if needed the current period.
        uint256 currentEpoch;
        if (_userClaimData.user != address(0)) {
            currentEpoch = _updateBountyPeriod(_bountyId, _userClaimData);
        } else {
            currentEpoch = _updateBountyPeriod(_bountyId, _proxyClaimData);
        }

        Bounty storage bounty = bounties[_bountyId];

        bytes32 gaugeHash = keccak256(abi.encodePacked(bounty.gauge, bounty.chainId));

        // Checking votes from user
        if (_userClaimData.user != address(0)) {
            amount += _getClaimable(_userClaimData, gaugeHash, _bountyId, bounty, currentEpoch);
        }

        if (_proxyClaimData.user != address(0)) {
            amount += _getClaimable(_proxyClaimData, gaugeHash, _bountyId, bounty, currentEpoch);
        }

        if (amount == 0) {
            return 0;
        }

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

        // Transfer reward to user.
        SafeTransferLib.safeTransfer(bounty.rewardToken, _recipient, amount);
        emit Claimed(_userClaimData.user, bounty.rewardToken, _bountyId, amount, feeAmount, currentEpoch);
    }

    /// @dev Internal function to avoid doing redundantly claim calculations (proxy + user)
    function _getClaimable(
        ClaimData memory _claimData,
        bytes32 gauge_hash,
        uint256 _bountyId,
        Bounty memory bounty,
        uint256 currentEpoch
    ) internal returns (uint256 amount) {
        // Get the last_vote timestamp.
        //uint256 lastVote = gaugeController.lastUserVote(_user, gauge_hash);

        //IGaugeVoting.VotedSlope memory userSlope = gaugeController.voteUserSlopes(_user, gauge_hash);

        if (
            !_canUserClaim(
                _claimData.user,
                _bountyId,
                bounty,
                _claimData.lastVote,
                currentEpoch,
                getCurrentEpoch(),
                amountClaimed[_bountyId],
                _claimData.userVoteSlope,
                _claimData.userVoteEnd
            )
        ) {
            return 0;
        }

        // Update the user's last claim period.
        lastUserClaim[_claimData.user][_bountyId] = currentEpoch;

        // Voting Power = userSlope * dt
        // with dt = lock_end - period.
        uint256 _bias = _getAddrBias(_claimData.userVoteSlope, _claimData.userVoteEnd, currentEpoch); // we are in the epoch after the voting period (active period)
        // Compute the reward amount based on
        // Reward / Total Votes.
        amount = _bias.mulWad(rewardPerVote[_bountyId]);
        // Compute the reward amount based on
        // the max price to pay.
        uint256 _amountWithMaxPrice = _bias.mulWad(bounty.maxRewardPerVote);
        // Distribute the _min between the amount based on votes, and price.
        amount = FixedPointMathLib.min(amount, _amountWithMaxPrice);
    }

    function _canUserClaim(
        address _user,
        uint256 _bountyId,
        Bounty memory _bounty,
        uint256 _lastVote,
        uint256 currentEpoch,
        uint256 _activePeriod,
        uint256 _amountClaimed,
        uint256 _userSlope,
        uint256 _userLockEnd
    ) internal view returns (bool) {
        // To ensure we will claim only on the active period week
        /// The user can't claim if:
        if (
            /// If the user is blacklisted.
            /// If the user has no voting power.
            // If the user already claimed for the current period.
            /// If the user's lock ended.
            /// If the user voted after the current period.
            /// If the bounty ended.
            /// User can only claim on the active period week;
            /// If the bounty is empty.
            isBlacklisted[_bountyId][_user] || _userSlope == 0 || lastUserClaim[_user][_bountyId] >= currentEpoch
                || currentEpoch >= _userLockEnd || currentEpoch <= _lastVote || currentEpoch >= _bounty.endTimestamp
                || currentEpoch != _activePeriod || _amountClaimed == _bounty.totalRewardAmount
        ) {
            return false;
        }
        return true;
    }

    /// @notice Update the current period for a given bounty.
    /// @param _bountyId Bounty ID.
    /// @return current/updated period.
    function _updateBountyPeriod(uint256 _bountyId, ClaimData memory _claimData) internal returns (uint256) {
        Period storage _activePeriod = activePeriod[_bountyId];

        uint256 currentEpoch = getCurrentEpoch();

        if (_activePeriod.id == 0 && currentEpoch == _activePeriod.timestamp && rewardPerVote[_bountyId] == 0) {
            // Check if there is an upgrade in queue and update the bounty.
            _checkForUpgrade(_bountyId);
            // Initialize reward per vote.
            // Only for the first period, and if not already initialized.
            _updateRewardPerToken(_bountyId, currentEpoch, _claimData);
        }

        // Increase Period after the active period (period on 2 weeks rounded down to the first, so week after)
        if (block.timestamp >= _activePeriod.timestamp + _TWOWEEKS) {
            // Checkpoint gauge to have up to date gauge weight.
            //gaugeController.checkpointGauge(bounties[bountyId].gauge, bounties[bountyId].chainId);

            // Check if there is an upgrade in queue and update the bounty.
            _checkForUpgrade(_bountyId);

            // Roll to next period.
            _rollOverToNextPeriod(_bountyId, currentEpoch, _claimData);

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
    /// @param _bountyId Bounty ID.
    /// @param _currentEpoch Next period timestamp.
    /// @param _claimData Claim Data
    function _rollOverToNextPeriod(uint256 _bountyId, uint256 _currentEpoch, ClaimData memory _claimData) internal {
        uint8 index = getActivePeriodPerBounty(_bountyId);

        Bounty storage bounty = bounties[_bountyId];

        bytes32 gauge_hash = keccak256(abi.encodePacked(bounty.gauge, bounty.chainId));

        uint256 periodsLeft = getPeriodsLeft(_bountyId);
        uint256 rewardPerPeriod;

        rewardPerPeriod = bounty.totalRewardAmount - amountClaimed[_bountyId];

        if (bounty.endTimestamp > _currentEpoch + _TWOWEEKS && periodsLeft > 1) {
            rewardPerPeriod = rewardPerPeriod.mulDiv(1, periodsLeft);
        }

        // Get adjusted slope without blacklisted addresses.
        uint256 gaugeBias = _getAdjustedBias(gauge_hash, bounty.blacklist, _currentEpoch, _claimData);

        rewardPerVote[_bountyId] = rewardPerPeriod.mulDiv(_BASE_UNIT, gaugeBias);
        activePeriod[_bountyId] = Period(index, _currentEpoch, rewardPerPeriod);

        emit PeriodRolledOver(_bountyId, index, _currentEpoch, rewardPerPeriod);
    }

    /// @notice Update the amount of reward per token for a given bounty.
    /// @dev This function is only called once per Bounty.
    function _updateRewardPerToken(uint256 _bountyId, uint256 _currentEpoch, ClaimData memory _claimData) internal {
        Bounty storage bounty = bounties[_bountyId];
        // Checkpoint gauge to have up to date gauge weight.
        //gaugeController.checkpointGauge(bounty.gauge, bounty.chainId);

        bytes32 gauge_hash = keccak256(abi.encodePacked(bounty.gauge, bounty.chainId));

        uint256 gaugeBias = _getAdjustedBias(gauge_hash, bounty.blacklist, _currentEpoch, _claimData);

        if (gaugeBias != 0) {
            rewardPerVote[_bountyId] = activePeriod[_bountyId].rewardPerPeriod.mulDiv(_BASE_UNIT, gaugeBias);
        }
    }

    ////////////////////////////////////////////////////////////////
    /// ---  VIEWS
    ///////////////////////////////////////////////////////////////

    /// @notice Get an estimate of the reward amount for a given user.
    /// @param user Address of the user.
    /// @param bountyId ID of the bounty.
    /// @dev Returns only claimable for current week. For previous weeks rewards, if it was checkpointed, use `checkpointedBalances`
    /// @return amount of rewards.
    /// Mainly used for UI.
    // function claimable(address user, uint256 bountyId) external view returns (uint256 amount) {
    //     //(,, address cakePoolProxy,,,,,) = escrow.getUserInfo(user); // Check if there is a proxy

    //     if (cakePoolProxy != address(0)) {
    //         amount += _activeClaimable(cakePoolProxy, bountyId);
    //     }

    //     amount += _activeClaimable(user, bountyId);
    // }

    ////////////////////////////////////////////////////////////////
    /// --- INTERNAL VIEWS
    ///////////////////////////////////////////////////////////////

    /// @notice Get adjusted slope from Gauge Controller for a given gauge address.
    /// Remove the weight of blacklisted addresses.
    /// @param _gaugeHash Hash of the gauge. (address + chainId)
    /// @param _addressesBlacklisted Array of blacklisted addresses.
    /// @param _period Timestamp to check vote weight.
    /// @param _claimData Claim data
    function _getAdjustedBias(
        bytes32 _gaugeHash,
        address[] memory _addressesBlacklisted,
        uint256 _period,
        ClaimData memory _claimData
    ) internal view returns (uint256 gaugeBias) {
        // Cache the user slope.
        //IGaugeVoting.VotedSlope memory userSlope;

        // Bias
        uint256 _bias;
        // Last Vote
        uint256 _lastVote;
        // Cache the length of the array.
        uint256 length = _addressesBlacklisted.length;
        // Cache blacklist.
        // Get the gauge slope.
        //gaugeBias = gaugeController.gaugePointsWeight(gauge_hash, period).bias;

        for (uint256 i = 0; i < length;) {
            // Get the user slope.
            //userSlope = gaugeController.voteUserSlopes(_addressesBlacklisted[i], gauge_hash);
            //_lastVote = gaugeController.lastUserVote(_addressesBlacklisted[i], gauge_hash);
            if (_period > _claimData.lastVote) {
                _bias = _getAddrBias(_claimData.userVoteSlope, _claimData.userVoteEnd, _period);
                gaugeBias -= _bias;
            }
            // Increment i.
            unchecked {
                ++i;
            }
        }
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

    /// @notice Set the recipient for a given address.
    /// @param _for Address to set the recipient for.
    /// @param _recipient Address of the recipient.
    function setRecipientFor(address _for, address _recipient) external onlyOwner {
        recipient[_for] = _recipient;

        emit RecipientSet(_for, _recipient);
    }

    function setBountyClaimer(address _claimer) external onlyOwner {
        emit ClaimerSet(claimer = _claimer);
    }

    function kill() external onlyOwner {
        isKilled = true;
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
    // function _activeClaimable(address user, uint256 bountyId) internal view returns (uint256 amount) {
    //     if (isBlacklisted[bountyId][user]) return 0;

    //     Bounty memory bounty = bounties[bountyId];
    //     // If there is an upgrade in progress but period hasn't been rolled over yet.
    //     Upgrade storage upgradedBounty = upgradeBountyQueue[bountyId];

    //     bytes32 gauge_hash = keccak256(abi.encodePacked(bounty.gauge, bounty.chainId));

    //     uint256 currentEpoch = getCurrentEpoch();

    //     // End timestamp of the bounty.
    //     uint256 endTimestamp = FixedPointMathLib.max(bounty.endTimestamp, upgradedBounty.endTimestamp);
    //     // Get the last_vote timestamp.
    //     uint256 lastVote = gaugeController.lastUserVote(user, gauge_hash);

    //     IGaugeVoting.VotedSlope memory userSlope = gaugeController.voteUserSlopes(user, gauge_hash);

    //     if (
    //         userSlope.slope == 0 || lastUserClaim[user][bountyId] >= currentEpoch || currentEpoch >= userSlope.end
    //             || currentEpoch <= lastVote || currentEpoch >= endTimestamp
    //             || currentEpoch < getActivePeriod(bountyId).timestamp || amountClaimed[bountyId] >= bounty.totalRewardAmount
    //     ) return 0;

    //     uint256 _rewardPerVote = rewardPerVote[bountyId];

    //     // If period updated.
    //     if (_rewardPerVote == 0 || (_rewardPerVote > 0 && getActivePeriod(bountyId).timestamp != currentEpoch)) {
    //         uint256 _rewardPerPeriod;

    //         if (upgradedBounty.numberOfEpochs != 0) {
    //             // Update max reward per vote.
    //             bounty.maxRewardPerVote = upgradedBounty.maxRewardPerVote;
    //             bounty.totalRewardAmount = upgradedBounty.totalRewardAmount;
    //         }

    //         uint256 periodsLeft = endTimestamp > currentEpoch ? (endTimestamp - currentEpoch) / _TWOWEEKS : 0;

    //         _rewardPerPeriod = bounty.totalRewardAmount - amountClaimed[bountyId];

    //         // Update reward per period if we're on the week after the active period
    //         if (endTimestamp > currentEpoch + _TWOWEEKS && periodsLeft > 1) {
    //             _rewardPerPeriod = _rewardPerPeriod.mulDiv(1, periodsLeft);
    //         }

    //         // Get Adjusted Slope without blacklisted addresses weight.
    //         uint256 gaugeBias = _getAdjustedBias(gauge_hash, bounty.blacklist, currentEpoch);

    //         _rewardPerVote = _rewardPerPeriod.mulDiv(_BASE_UNIT, gaugeBias);
    //     }
    //     // Get user voting power.
    //     uint256 _bias = _getAddrBias(userSlope.slope, userSlope.end, currentEpoch);

    //     // Estimation of the amount of rewards.
    //     amount = _bias.mulWad(_rewardPerVote);
    //     // Compute the reward amount based on
    //     // the max price to pay.
    //     uint256 _amountWithMaxPrice = _bias.mulWad(bounty.maxRewardPerVote);
    //     // Distribute the _min between the amount based on votes, and price.
    //     amount = FixedPointMathLib.min(amount, _amountWithMaxPrice);

    //     uint256 _amountClaimed = amountClaimed[bountyId];
    //     // Update the amount claimed.
    //     if (amount + _amountClaimed > bounty.totalRewardAmount) {
    //         amount = bounty.totalRewardAmount - _amountClaimed;
    //     }
    //     // Substract fees.
    //     if (fee != 0) {
    //         amount = amount.mulWad(_BASE_UNIT - fee);
    //     }
    // }

    function getVersion() external pure returns (string memory) {
        return "2.2.1";
    }
}
