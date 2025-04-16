// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Reward, TokenAmount} from "../../interfaces/internals/tgUSD/IRewards.sol";
import {ICollateral} from "../../interfaces/internals/tgUSD/ICollateral.sol";
import {IRewardAccumulator} from "../../interfaces/internals/tgUSD/IRewardAccumulator.sol";
import {IIRCalculator} from "../../interfaces/internals/tgUSD/IIRCalculator.sol";

import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import "forge-std/console.sol";

contract RewardAccumulator is IRewardAccumulator, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant DENOMINATOR = 100_000;

    /// @dev Duration that rewards are streamed over
    uint256 public constant REWARDS_DURATION = 7 days; // 1 week

    IControlTower public controlTower;

    IIRCalculator public irCalculator;

    /// @notice Percentage of reward given to harvester. 1_000 = 1%
    mapping(address => uint256) public harvesterFeePercentage;

    /// @notice Percentage of reward of rewards to distribute to borrowers. 50_000 = 50%
    mapping(address => uint256) public lastRewardCuts;

    /// @notice List of reward tokens
    mapping(address => IERC20[]) public rewardTokens;

    /// @notice Reward data associated to a reward token
    mapping(address => mapping(IERC20 => Reward)) public rewardData; // market => token => reward data

    /// @notice Reward amount already claimed to an user for a reward token
    mapping(address => mapping(address => mapping(IERC20 => uint256))) public userRewardPerTokenPaid; // market => user => reward token => amount

    /// @notice Reward amount for a reward token for a user
    mapping(address => mapping(address => mapping(IERC20 => uint256))) public rewards; // market => user => reward token => amount

    /// @notice Amount of fee that DAO can withdraw for a given token
    mapping(IERC20 => uint256) public cutFeeForToken;

    event RewardNotified(IERC20 _token, uint256 _reward);
    event RewardPaid(address market, address _user, IERC20 _rewardToken, uint256 _reward);
    event Recovered(address market, IERC20 _token, uint256 _amount);
    event RewardAdded(address market, IERC20 _rewardToken);
    event RewardDistributorApproved(address market, IERC20 _reward, address _distributor, bool _state);

    error NoRewardsToClaimFromContract(address contractAddr);
    error IncorrectRewardLength(uint256 rewardLengthInParam, uint256 realRewardLength);
    error NoRewardToMultiClaim();
    error NoRewardToSimpleClaim();
    error NotAMarketRewards();

    error HarvesterFeeToHigh();
    error NothingToProcess();
    error RewardAlreadyAdded(IERC20 erc20);

    modifier updateReward(address market, address account) {
        _updateReward(market, account);
        _;
    }

    constructor(address _owner, IControlTower _controlTower, IIRCalculator _irCalculator) Ownable(_owner) {
        controlTower = _controlTower;
        irCalculator = _irCalculator;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       INTERNALS
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Fetch the reward amount of a token based on the period
     * @param _rewardToken Address of the reward token
     * @return Total reward amount of the token
     */
    function _rewardPerToken(address market, IERC20 _rewardToken, uint256 totalCollateral) internal view returns (uint256) {
        if (totalCollateral == 0) {
            return rewardData[market][_rewardToken].rewardPerTokenStored;
        }

        return
            rewardData[market][_rewardToken].rewardPerTokenStored +
            (((_lastTimeRewardApplicable(rewardData[market][_rewardToken].periodFinish) - rewardData[market][_rewardToken].lastUpdateTime) *
                rewardData[market][_rewardToken].rewardRate *
                1e18) / totalCollateral);
    }

    /**
     * @notice Fetch the amount earned
     * @param _user Address of the user
     * @param _rewardToken Address of the reward token
     * @param _balance Balance
     * @return Reward amount to claim for the user
     */
    function _earned(address market, address _user, IERC20 _rewardToken, uint256 _balance, uint256 totalCollateral) internal view returns (uint256) {
        return
            (_balance * (_rewardPerToken(market, _rewardToken, totalCollateral) - userRewardPerTokenPaid[market][_user][_rewardToken])) /
            1e18 +
            rewards[market][_user][_rewardToken];
    }

    function _lastTimeRewardApplicable(uint128 _finishTime) internal view returns (uint128) {
        return block.timestamp < _finishTime ? uint128(block.timestamp) : uint128(_finishTime);
    }

    function updateRewards(address account) external {
        require(controlTower.isMarket(msg.sender), NotAMarketRewards());
        _updateReward(msg.sender, account);
    }

    /**
     * @notice Update reward data for every reward tokens for an address
     * @param market Address of the user
     * @param account Address of the user
     */
    function _updateReward(address market, address account) internal {
        uint256 userBal = ICollateral(market).collateralBalances(account);
        uint256 totalCollateral = ICollateral(market).totalCollateral();
        uint256 rewardLength = rewardTokens[market].length;
        for (uint256 i; i < rewardLength; ) {
            IERC20 token = rewardTokens[market][i];

            rewardData[market][token].rewardPerTokenStored = _rewardPerToken(market, token, totalCollateral);
            rewardData[market][token].lastUpdateTime = _lastTimeRewardApplicable(rewardData[market][token].periodFinish);

            if (account != address(0)) {
                rewards[market][account][token] = _earned(market, account, token, userBal, totalCollateral);
                userRewardPerTokenPaid[market][account][token] = rewardData[market][token].rewardPerTokenStored;
            }

            unchecked {
                ++i;
            }
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CLAIM REWARDS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @dev Updates all rewards for the user and returns the amount of rewards to claim
     * @param market  Market address to claim rewards from
     * @param account Address to claim rewards for
     */
    function _claimRewards(address market, address account) internal updateReward(market, account) returns (TokenAmount[] memory) {
        uint256 rewardTokensLength = rewardTokens[market].length;
        TokenAmount[] memory tokenAmounts = new TokenAmount[](rewardTokensLength);
        uint256 counter;
        for (uint256 tokenIndex; tokenIndex < rewardTokensLength; ) {
            IERC20 _rewardToken = rewardTokens[market][tokenIndex];
            uint256 rewardAmount = rewards[market][account][_rewardToken];

            if (rewardAmount != 0) {
                rewards[market][account][_rewardToken] = 0;
                tokenAmounts[counter++] = TokenAmount({token: _rewardToken, amount: rewardAmount});
                emit RewardPaid(market, account, _rewardToken, rewardAmount);
            }

            unchecked {
                ++tokenIndex;
            }
        }

        /// @dev Reduce length of tokenAmounts struct to not return useless 0
        if (tokenAmounts.length != 0) {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                mstore(tokenAmounts, sub(mload(tokenAmounts), sub(rewardTokensLength, counter)))
            }
        }

        return tokenAmounts;
    }

    /**
     *  @notice Claim rewards on one staking contract only
     *  @param market The erc20 to claim the rewards on
     */
    function claimSimple(address market) external {
        require(controlTower.isMarket(market), NotAMarketRewards());

        TokenAmount[] memory tokenAmounts = _claimRewards(market, msg.sender);

        require(tokenAmounts.length != 0, NoRewardToSimpleClaim());

        for (uint256 erc20Id; erc20Id < tokenAmounts.length; ) {
            tokenAmounts[erc20Id].token.safeTransfer(msg.sender, tokenAmounts[erc20Id].amount);
            unchecked {
                ++erc20Id;
            }
        }
    }

    /**
     *  @notice Claim rewards on one staking contract only
     *  @param markets Array of contract to claim the rewards on
     *  @param rewardLength Amount of different tokens to claim as a reward
     */
    function claimMultiple(address[] calldata markets, uint256 rewardLength) external {
        // We save this length on his own variable, to not miss with the assembly manipulations
        uint256 marketsLen = markets.length;
        IERC20[] memory tokenList = new IERC20[](rewardLength);
        uint256 actualErc20Index;

        // Reverts if one of the market passed in parameter is not one.
        // It protects us agains a malicious user input.
        controlTower.isContractsMarkets(markets);

        // Iterates through all of the markets to claim rewards
        for (uint256 marketIndex; marketIndex < marketsLen; ) {
            address market = markets[marketIndex];

            // Get and update the amount of rewards to claim
            TokenAmount[] memory tokenAmountsToClaim = _claimRewards(market, msg.sender);
            // If the rewards returned by the gUSD is an empty array,
            require(tokenAmountsToClaim.length != 0, NoRewardsToClaimFromContract(address(market)));
            // Iterates over all erc20 received from the claim on the gUSD
            for (uint256 tokenIndex; tokenIndex < tokenAmountsToClaim.length; ) {
                IERC20 erc20 = tokenAmountsToClaim[tokenIndex].token;
                // If token is seen the first time (tokensToClaim[token] == 0)
                uint256 rewardAmount = _tLoadUintForAddress(address(erc20));

                if (rewardAmount == 0) {
                    // Increment tokenList length & add new token on new index
                    tokenList[actualErc20Index] = erc20;
                    unchecked {
                        ++actualErc20Index;
                    }
                }
                // Increment storage value
                _tStoreUintForAddress(address(erc20), rewardAmount + tokenAmountsToClaim[tokenIndex].amount);
                unchecked {
                    ++tokenIndex;
                }
            }

            unchecked {
                ++marketIndex;
            }
        }

        require(rewardLength == actualErc20Index, IncorrectRewardLength(rewardLength, actualErc20Index));

        // Iterate through tokenList
        bool isSomethingToClaim;
        for (uint256 tokenIndex; tokenIndex < tokenList.length; ) {
            IERC20 token = tokenList[tokenIndex];
            uint256 amountClaim = _tLoadUintForAddress(address(token));

            if (amountClaim != 0) {
                isSomethingToClaim = true;
                token.safeTransfer(msg.sender, amountClaim);
                // Erase transient for the token
                _tStoreUintForAddress(address(token), 0);
            }

            unchecked {
                ++tokenIndex;
            }
        }
        require(isSomethingToClaim, NoRewardToMultiClaim());
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    FEES UPDATER
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Increment dao fees that will be transferred in this contract during a process rewards.
     *         This function is only callable by an updater (scvUSD or gUSD).
     * @param tokens array of token to claim
     */
    function claimCutFees(IERC20[] memory tokens) external {
        address _feeTreasury = controlTower.feeTreasury();
        for (uint256 erc20Id; erc20Id < tokens.length; ) {
            IERC20 token = tokens[erc20Id];
            token.transfer(_feeTreasury, cutFeeForToken[token]);

            delete cutFeeForToken[token];
            unchecked {
                ++erc20Id;
            }
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            INTERNALS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function _tStoreUintForAddress(address location, uint256 value) private {
        assembly {
            tstore(location, value)
        }
    }

    function _tLoadUintForAddress(address location) private view returns (uint256 value) {
        assembly {
            value := tload(location)
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            OWNER
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Set the percentage of rewards to be sent to the splitter as a DAO fees.
     * @param market          rewards percentage value
     * @param newRewardTokens rewards percentage value
     */
    function addNewRewards(address market, IERC20[] calldata newRewardTokens) external onlyOwner {
        for (uint256 i; i < newRewardTokens.length; ) {
            IERC20 _newRewardToken = newRewardTokens[i];
            /// @dev If lastUpdateTime is equal to 0, it means the token is not already added as a reward
            require(rewardData[market][_newRewardToken].lastUpdateTime == 0, RewardAlreadyAdded(_newRewardToken));

            rewardTokens[market].push(_newRewardToken);
            rewardData[market][_newRewardToken].lastUpdateTime = uint128(block.timestamp);
            rewardData[market][_newRewardToken].periodFinish = uint128(block.timestamp);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Set the percentage of rewards on the rewards streamed to borrowers to send to the processor.
     * @param _harvesterFeePercentage Percentage fee of the rewards streamed to borrowers.
     */
    function setHarvesterFeePercentage(address market, uint256 _harvesterFeePercentage) external onlyOwner {
        require(_harvesterFeePercentage <= 2_000, HarvesterFeeToHigh());
        harvesterFeePercentage[market] = _harvesterFeePercentage;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            VIEWS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function lastTimeRewardApplicable(address market, IERC20 _rewardToken) external view returns (uint256) {
        return _lastTimeRewardApplicable(rewardData[market][_rewardToken].periodFinish);
    }

    function rewardPerToken(address market, IERC20 _rewardToken) external view returns (uint256) {
        return _rewardPerToken(market, _rewardToken, ICollateral(market).totalCollateral());
    }

    function getRewardForDuration(address market, IERC20 _rewardToken) external view returns (uint256) {
        return rewardData[market][_rewardToken].rewardRate * REWARDS_DURATION;
    }

    function getRewardTokens(address market) external view returns (IERC20[] memory) {
        return rewardTokens[market];
    }

    function processRewards(address harvestFeeReceiver, TokenAmount[] memory rewardAmounts) external {
        require(controlTower.isMarket(msg.sender), NotAMarketRewards());
        uint256 rewardTokensLength = rewardAmounts.length;
        require(rewardTokensLength != 0, NothingToProcess());

        _updateReward(msg.sender, address(0));
        uint256 rewardCut = lastRewardCuts[msg.sender];

        // Actualize reward cut
        lastRewardCuts[msg.sender] = irCalculator.computeRCForMarket(msg.sender);

        uint256 _harvesterFeePercetage = harvesterFeePercentage[msg.sender];

        for (uint256 tokenIndex; tokenIndex < rewardTokensLength; ) {
            IERC20 rewardToken = rewardAmounts[tokenIndex].token;
            uint256 rewardToProcess = rewardAmounts[tokenIndex].amount;

            // Calculate and sends harvester fees
            uint256 harvesterFees = (rewardToProcess * _harvesterFeePercetage) / DENOMINATOR;

            if (harvesterFees != 0) {
                rewardToken.safeTransfer(harvestFeeReceiver, harvesterFees);
            }

            uint256 remainingRewards = rewardToProcess - harvesterFees;

            uint256 rewardAmountStreamed;
            if (rewardCut != 0) {
                uint256 rewardAmountCut = (remainingRewards * rewardCut) / DENOMINATOR;
                cutFeeForToken[rewardToken] += rewardAmountCut;
                rewardAmountStreamed = remainingRewards - rewardAmountCut;
            } else {
                rewardAmountStreamed = remainingRewards;
            }

            Reward storage rData = rewardData[msg.sender][rewardToken];

            if (block.timestamp >= rData.periodFinish) {
                rData.rewardRate = rewardAmountStreamed / REWARDS_DURATION;
            } else {
                rData.rewardRate = (rewardAmountStreamed + (rData.periodFinish - block.timestamp) * rData.rewardRate) / REWARDS_DURATION;
            }

            rData.lastUpdateTime = uint128(block.timestamp);
            rData.periodFinish = uint128(block.timestamp + REWARDS_DURATION);

            emit RewardNotified(rewardToken, rewardAmountStreamed);

            unchecked {
                ++tokenIndex;
            }
        }
    }

    /**
     * @notice Get the claimable amount of all reward tokens for the given address
     * @param _account Address of the user
     * @return userRewards Array of rewards
     */
    function claimableRewards(address market, address _account) external view returns (TokenAmount[] memory userRewards) {
        userRewards = new TokenAmount[](rewardTokens[market].length);

        uint256 collateralBalance = ICollateral(market).collateralBalances(_account);
        uint256 totalCollateral = ICollateral(market).totalCollateral();

        for (uint256 erc20Id; erc20Id < userRewards.length; ) {
            IERC20 token = rewardTokens[market][erc20Id];
            userRewards[erc20Id].token = token;
            userRewards[erc20Id].amount = _earned(market, _account, token, collateralBalance, totalCollateral);

            unchecked {
                ++erc20Id;
            }
        }

        return userRewards;
    }
}
