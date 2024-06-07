// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.20;
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
import {Platform} from "src/Platform.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {IGaugeControllerOracle} from "src/interfaces/IGaugeControllerOracle.sol";

/// @title PlatformClaimable
/// @notice View contract for Platform Votemarket.
contract PlatformClaimable is Owned {
    using FixedPointMathLib for uint256;

    /// @notice Week in seconds.
    uint256 private constant _WEEK = 1 weeks;

    /// @notice Base unit for fixed point compute.
    uint256 private constant _BASE_UNIT = 1e18;

    IGaugeControllerOracle public gaugeController;


    ////////////////////////////////////////////////////////////
    /// --- STRUCTS
    ////////////////////////////////////////////////////////////
    
    struct ProofState {
        IGaugeControllerOracle.Point gaugeBias;
        IGaugeControllerOracle.VotedSlope userSlope;
        uint256 lastVote;
    }


    ////////////////////////////////////////////////////////////////
    /// --- CONSTRUCTOR
    ///////////////////////////////////////////////////////////////

    /// @notice Create Bounty platform.
    /// @param _gaugeController Address of the gauge controller.
    constructor(address _gaugeController) Owned(msg.sender) {
        gaugeController = IGaugeControllerOracle(_gaugeController);
    }

    // /// @notice Get an estimate of the reward amount for a given user.
    // /// @param user Address of the user.
    // /// @param bountyId ID of the bounty.
    // /// @return amount of rewards.
    /// Mainly used for UI.
    function claimable(Platform platform, uint256 bountyId, Platform.ProofData memory proofData)
        external
        view
        returns (uint256 amount)
    {
        if (platform.isBlacklisted(bountyId, proofData.user)) return 0;

        uint256 currentPeriod = getCurrentPeriod();

        if (currentPeriod != gaugeController.activePeriod()) return 0;

        Platform.Bounty memory bounty = platform.getBounty(bountyId);

        Platform.Upgrade memory upgradedBounty = platform.getUpgradedBountyQueued(bountyId);

        // End timestamp of the bounty.
        uint256 endTimestamp = FixedPointMathLib.max(bounty.endTimestamp, upgradedBounty.endTimestamp);

        ProofState memory proofState;

        (proofState.gaugeBias, proofState.userSlope, proofState.lastVote,) =
            gaugeController.extractProofState(proofData.user, bounty.gauge, proofData.headerRlp, proofData.userProofRlp);
        if (
            proofState.userSlope.slope == 0 || platform.lastUserClaim(proofData.user, bountyId) >= currentPeriod
                || currentPeriod >= proofState.userSlope.end || currentPeriod <= proofState.lastVote || currentPeriod >= endTimestamp
                || currentPeriod < platform.getActivePeriod(bountyId).timestamp
                || platform.amountClaimed(bountyId) >= bounty.totalRewardAmount
        ) return 0;

        uint256 _rewardPerVote = platform.rewardPerVote(bountyId);
        // If period updated.
        if (
            _rewardPerVote == 0 || (_rewardPerVote > 0 && platform.getActivePeriod(bountyId).timestamp != currentPeriod)
        ) {
            uint256 _rewardPerPeriod;

            if (upgradedBounty.numberOfPeriods != 0) {
                // Update max reward per vote.
                bounty.maxRewardPerVote = upgradedBounty.maxRewardPerVote;
                bounty.totalRewardAmount = upgradedBounty.totalRewardAmount;
            }

            uint256 periodsLeft = endTimestamp > currentPeriod ? (endTimestamp - currentPeriod) / _WEEK : 0;
            _rewardPerPeriod = bounty.totalRewardAmount - platform.amountClaimed(bountyId);

            if (endTimestamp > currentPeriod + _WEEK && periodsLeft > 1) {
                _rewardPerPeriod = _rewardPerPeriod.mulDiv(1, periodsLeft);
            }

            _rewardPerVote = _rewardPerPeriod.mulDiv(
                _BASE_UNIT,
                // Get Adjusted Slope without blacklisted addresses weight or just weight if not set yet.
                platform.gaugeAdjustedBias(bounty.gauge, gaugeController.last_eth_block_number()) > 0
                    ? platform.gaugeAdjustedBias(bounty.gauge, gaugeController.last_eth_block_number())
                    : proofState.gaugeBias.bias
            );
        }

        // Get user voting power.
        uint256 _bias = _getAddrBias(proofState.userSlope.slope, proofState.userSlope.end, currentPeriod);
        // Estimation of the amount of rewards.
        amount = _bias.mulWad(_rewardPerVote);
        // Compute the reward amount based on
        // the max price to pay.
        uint256 _amountWithMaxPrice = _bias.mulWad(bounty.maxRewardPerVote);
        // Distribute the _min between the amount based on votes, and price.
        amount = FixedPointMathLib.min(amount, _amountWithMaxPrice);

        uint256 _amountClaimed = platform.amountClaimed(bountyId);

        // Update the amount claimed.
        if (amount + _amountClaimed > bounty.totalRewardAmount) {
            amount = bounty.totalRewardAmount - _amountClaimed;
        }
        // Substract fees.
        if (platform.fee() != 0) {
            amount = amount.mulWad(_BASE_UNIT - platform.fee());
        }
    }

    function getRemainingPerPeriod(Platform platform, uint256 bountyId) external view returns (uint256) {
        Platform.Bounty memory bounty = platform.getBounty(bountyId);
        Platform.Upgrade memory upgradedBribe = platform.getUpgradedBountyQueued(bountyId);

        uint256 currentPeriod = getCurrentPeriod();
        uint256 endTimestamp = FixedPointMathLib.max(bounty.endTimestamp, upgradedBribe.endTimestamp);
        uint256 totalRewardAmount = FixedPointMathLib.max(bounty.totalRewardAmount, upgradedBribe.totalRewardAmount);

        uint256 periodsLeft = endTimestamp > currentPeriod ? (endTimestamp - currentPeriod) / _WEEK : 0;

        uint256 _rewardPerPeriod = totalRewardAmount - platform.amountClaimed(bountyId);

        if (endTimestamp > currentPeriod + _WEEK && periodsLeft > 1) {
            _rewardPerPeriod = _rewardPerPeriod.mulDiv(1, periodsLeft);
        }

        return _rewardPerPeriod;
    }

    /// @notice Return the current period based on Gauge Controller rounding.
    function getCurrentPeriod() public view returns (uint256) {
        return (block.timestamp / _WEEK) * _WEEK;
    }

    ////////////////////////////////////////////////////////////
    /// --- INTERNAL
    ////////////////////////////////////////////////////////////

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
    ////////////////////////////////////////////////////////////
    /// --- ONLY OWNER
    ////////////////////////////////////////////////////////////

    function setGaugeController(address _gaugeController) external onlyOwner {
        gaugeController = IGaugeControllerOracle(_gaugeController);
    }
}
