// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ICollateral} from "../../interfaces/internals/tgUSD/ICollateral.sol";
import {IRewardAccumulator, RCParams, Reward, TokenAmount} from "../../interfaces/internals/tgUSD/IRewardAccumulator.sol";
import {IAggregatorStablePriceV3} from "../../interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";
import {IMarketExternalActions} from "../../interfaces/internals/tgUSD/IMarketExternalActions.sol";

import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import "forge-std/console.sol";

contract RewardAccumulator is IRewardAccumulator, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant DENOMINATOR = 100_000;

    /// @dev Duration that rewards are streamed over
    uint256 public constant REWARDS_DURATION = 7 days; // 1 week

    IControlTower public controlTower;

    IAggregatorStablePriceV3 public tgUSDOracle;

    /// @notice Gives the parameter of the market
    mapping(address => RCParams) public rcParams;

    /// @notice Percentage of reward of rewards to distribute to borrowers. 50_000 = 50%
    mapping(address => uint256) public lastRewardCuts; // Market => Reward Cut

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

    event RewardNotified(address market, IERC20 _token, uint256 streamed, uint256 harvesterFee, uint256 rewardCut);
    event RewardPaid(address market, address _user, IERC20 _rewardToken, uint256 _reward);

    error NoRewardsToClaimFromContract(address contractAddr);
    error IncorrectRewardLength(uint256 rewardLengthInParam, uint256 realRewardLength);
    error NoRewardToMultiClaim();
    error NoRewardToSimpleClaim();
    error NotAMarketRewards();
    error CantAddCollatTokenAsReward();

    error HarvesterFeeToHigh();
    error NothingToProcess();
    error RewardAlreadyAdded(IERC20 erc20);

    error CallerNotOwnerOrMarketCreator(address caller);

    modifier updateReward(address market, address account) {
        (uint256 collateralBalance, uint256 totalCollateral) = ICollateral(market).getBalanceAndTotalCollateral(account);
        _updateReward(market, account, collateralBalance, totalCollateral);
        _;
    }

    //TODO Add check for params
    modifier verifyRCParams(RCParams calldata _rcParam) {
        require(_rcParam.startCutPrice <= 1e18);
        if (_rcParam.stepAmount == 2) {
            require(_rcParam.startCutPercentage < _rcParam.endCutPercentage);
            require(_rcParam.startCutPrice > _rcParam.endCutPrice);
        }
        _;
    }

    constructor(address _owner, IControlTower _controlTower, IAggregatorStablePriceV3 _tgUSDOracle) Ownable(_owner) {
        controlTower = _controlTower;
        tgUSDOracle = _tgUSDOracle;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       INTERNALS
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function getRewardData(address market, IERC20 token) external view returns (Reward memory) {
        return rewardData[market][token];
    }

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

    function updateRewards(address account, uint256 collateralBalance, uint256 totalCollateral) external {
        require(controlTower.isMarket(msg.sender), NotAMarketRewards());
        _updateReward(msg.sender, account, collateralBalance, totalCollateral);
    }

    /**
     * @notice Update reward data for every reward tokens for an address
     * @param market Address of the user
     * @param account Address of the user
     */
    function _updateReward(address market, address account, uint256 collateralBalance, uint256 totalCollateral) internal {
        uint256 rewardLength = rewardTokens[market].length;

        for (uint256 i; i < rewardLength; ) {
            IERC20 token = rewardTokens[market][i];

            rewardData[market][token].rewardPerTokenStored = _rewardPerToken(market, token, totalCollateral);
            rewardData[market][token].lastUpdateTime = _lastTimeRewardApplicable(rewardData[market][token].periodFinish);

            if (account != address(0)) {
                rewards[market][account][token] = _earned(market, account, token, collateralBalance, totalCollateral);
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
        // Reverts if one of the market passed in parameter is not one.
        // It protects us agains a malicious user input.
        controlTower.isContractsMarkets(markets);
        // We save this length on his own variable, to not miss with the assembly manipulations
        uint256 marketsLen = markets.length;
        TokenAmount[] memory totals = new TokenAmount[](rewardLength);
        uint256 actualErc20Index;

        // Iterates through all of the markets to claim rewards
        for (uint256 marketIndex; marketIndex < marketsLen; ) {
            address market = markets[marketIndex];

            // Get and update the amount of rewards to claim
            TokenAmount[] memory tokenAmountsToClaim = _claimRewards(market, msg.sender);
            // If the rewards returned by the gUSD is an empty array,
            require(tokenAmountsToClaim.length != 0, NoRewardsToClaimFromContract(address(market)));
            // Iterates over all erc20 received from the claim on the gUSD
            for (uint256 tokenIndex; tokenIndex < tokenAmountsToClaim.length; ) {
                IERC20 rewardToken = tokenAmountsToClaim[tokenIndex].token;
                // If token is seen the first time (tokensToClaim[token] == 0)
                uint256 index = _tLoadUintForAddress(address(rewardToken));

                if (index != 0) {
                    totals[index - 1].amount += tokenAmountsToClaim[tokenIndex].amount;
                } else {
                    totals[actualErc20Index++] = TokenAmount({token: rewardToken, amount: tokenAmountsToClaim[tokenIndex].amount});
                    _tStoreUintForAddress(address(rewardToken), actualErc20Index);
                }

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
        for (uint256 i; i < totals.length; ) {
            IERC20 token = totals[i].token;
            uint256 amount = totals[i].amount;
            if (amount != 0) {
                isSomethingToClaim = true;
                token.safeTransfer(msg.sender, amount);
            }
            // Erase transient for the token
            _tStoreUintForAddress(address(token), 0);

            unchecked {
                ++i;
            }
        }
        require(isSomethingToClaim, NoRewardToMultiClaim());
    }

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
     * @notice Get the claimable amount of all reward tokens for the given address
     * @param _account Address of the user
     * @return userRewards Array of rewards
     */
    function claimableRewards(address market, address _account) external view returns (TokenAmount[] memory userRewards) {
        userRewards = new TokenAmount[](rewardTokens[market].length);

        (uint256 collateralBalance, uint256 totalCollateral) = ICollateral(market).getBalanceAndTotalCollateral(_account);

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
        IERC20 _collatToken = ICollateral(market).collatToken();
        for (uint256 i; i < newRewardTokens.length; ) {
            IERC20 _newRewardToken = newRewardTokens[i];
            /// If lastUpdateTime is equal to 0, it means the token is not already added as a reward
            require(rewardData[market][_newRewardToken].lastUpdateTime == 0, RewardAlreadyAdded(_newRewardToken));
            require(_collatToken != _newRewardToken, CantAddCollatTokenAsReward());

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
     * @param _harvestFeePercentage Percentage fee of the rewards streamed to borrowers.
     */
    function setHarvesterFeePercentage(address market, uint16 _harvestFeePercentage) external onlyOwner {
        require(_harvestFeePercentage <= 2_000, HarvesterFeeToHigh());
        rcParams[market].harvestFeePercentage = _harvestFeePercentage;
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

    function getRCParams(address market) external view returns (RCParams memory) {
        return rcParams[market];
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    HARVEST REWARDS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function processRewards(address market, address harvestFeeReceiver) public {
        require(controlTower.isMarket(market), NotAMarketRewards());
        _updateReward(market, address(0), 0, ICollateral(market).totalCollateral());
        TokenAmount[] memory rewardAmounts = IMarketExternalActions(market).claimUnderlyingRewards(rewardTokens[market]);
        uint256 rewardTokensLength = rewardAmounts.length;
        // require(rewardTokensLength != 0, NothingToProcess()); TODO Cannot modify some RC params if no rewards ?

        uint256 rewardCutPercentage = lastRewardCuts[market];

        RCParams memory _rcParams = rcParams[market];

        // Actualize reward cut
        lastRewardCuts[market] = _calculateRC(tgUSDOracle.price_w(), _rcParams);

        uint16 harvestFeePercentage = _rcParams.harvestFeePercentage;

        for (uint256 tokenIndex; tokenIndex < rewardTokensLength; ) {
            IERC20 rewardToken = rewardAmounts[tokenIndex].token;

            (uint256 rewardCutAmount, uint256 harvesterAmount) = _processRewards(market, rewardToken, rewardAmounts[tokenIndex].amount, harvestFeePercentage, rewardCutPercentage);
            if (rewardCutAmount != 0) {
                cutFeeForToken[rewardToken] += rewardCutAmount;
            }
            if (harvesterAmount != 0) {
                rewardToken.safeTransfer(harvestFeeReceiver, harvesterAmount);
            }

            unchecked {
                ++tokenIndex;
            }
        }
    }

    struct ProcessableRewards {
        IERC20 rewardToken;
        uint256 amountForFees;
        uint256 amountForHarvester;
    }

    function processMultiRewards(address[] calldata markets, address harvestFeeReceiver, uint256 rewardLength) external {
        // Reverts if one of the market passed in parameter is not one.
        // It protects us agains a malicious user input.
        controlTower.isContractsMarkets(markets);

        uint256 tgUSDPrice = tgUSDOracle.price_w();

        ProcessableRewards[] memory processables = new ProcessableRewards[](rewardLength);
        uint256 actualErc20Index;

        for (uint256 i = 0; i < markets.length; ) {
            address market = markets[i];
            _updateReward(market, address(0), 0, ICollateral(market).totalCollateral());
            TokenAmount[] memory rewardAmounts = IMarketExternalActions(market).claimUnderlyingRewards(rewardTokens[market]);
            uint256 rewardTokensLength = rewardAmounts.length;

            uint256 rewardCutPercentage = lastRewardCuts[market];
            RCParams memory _rcParams = rcParams[market];
            uint16 harvestFeePercentage = _rcParams.harvestFeePercentage;

            // Actualize reward cut
            lastRewardCuts[market] = _calculateRC(tgUSDPrice, _rcParams);

            for (uint256 j; j < rewardTokensLength; ) {
                IERC20 rewardToken = rewardAmounts[j].token;
                (uint256 rewardCutAmount, uint256 harvesterAmount) = _processRewards(market, rewardToken, rewardAmounts[j].amount, harvestFeePercentage, rewardCutPercentage);

                // If token is seen the first time (tokensToClaim[token] == 0)
                uint256 index = _tLoadUintForAddress(address(rewardToken));

                if (index != 0) {
                    processables[index - 1].amountForFees += rewardCutAmount;
                    processables[index - 1].amountForHarvester += harvesterAmount;
                }
                // First time the token is iterated
                else {
                    processables[actualErc20Index++] = ProcessableRewards({rewardToken: rewardToken, amountForFees: rewardCutAmount, amountForHarvester: harvesterAmount});
                    _tStoreUintForAddress(address(rewardToken), actualErc20Index);
                }

                unchecked {
                    ++j;
                }
            }

            // require(rewardTokensLength != 0, NothingToProcess()); TODO Cannot modify some RC params if no rewards ?
            unchecked {
                ++i;
            }
        }

        require(rewardLength == actualErc20Index, IncorrectRewardLength(rewardLength, actualErc20Index));

        for (uint256 i; i < processables.length; ) {
            IERC20 rewardToken = processables[i].rewardToken;
            uint256 amountForFees = processables[i].amountForFees;
            uint256 amountForHarvester = processables[i].amountForHarvester;

            if (amountForFees != 0) {
                cutFeeForToken[rewardToken] += amountForFees;
            }

            if (amountForHarvester != 0) {
                rewardToken.safeTransfer(harvestFeeReceiver, amountForHarvester);
            }

            _tStoreUintForAddress(address(rewardToken), 0);

            unchecked {
                ++i;
            }
        }
    }

    function _processRewards(
        address market,
        IERC20 rewardToken,
        uint256 rewardToProcess,
        uint16 _harvesterFeePercentage,
        uint256 rewardCutPercentage
    ) internal returns (uint256, uint256) {
        // Calculate and sends harvester fees
        uint256 harvesterFees = (rewardToProcess * _harvesterFeePercentage) / DENOMINATOR;
        uint256 rewardCutAmount;

        uint256 remainingRewards = rewardToProcess - harvesterFees;
        uint256 rewardAmountStreamed;

        if (rewardCutPercentage != 0) {
            rewardCutAmount = (remainingRewards * rewardCutPercentage) / DENOMINATOR;
            rewardAmountStreamed = remainingRewards - rewardCutAmount;
        } else {
            rewardAmountStreamed = remainingRewards;
        }

        Reward storage rData = rewardData[market][rewardToken];

        if (block.timestamp >= rData.periodFinish) {
            rData.rewardRate = rewardAmountStreamed / REWARDS_DURATION;
        } else {
            rData.rewardRate = (rewardAmountStreamed + (rData.periodFinish - block.timestamp) * rData.rewardRate) / REWARDS_DURATION;
        }

        rData.lastUpdateTime = uint128(block.timestamp);
        rData.periodFinish = uint128(block.timestamp + REWARDS_DURATION);

        emit RewardNotified(market, rewardToken, rewardAmountStreamed, harvesterFees, rewardCutAmount);

        return (rewardCutAmount, harvesterFees);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       REWARD CUT
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function initializeMarket(address market, RCParams calldata _rcParams) external verifyRCParams(_rcParams) {
        require(controlTower.isMarketCreator(msg.sender), CallerNotOwnerOrMarketCreator(msg.sender));
        lastRewardCuts[market] = _calculateRC(tgUSDOracle.price_w(), _rcParams);
        rcParams[market] = _rcParams;
    }

    function updateRCParams(address market, RCParams calldata _rcParam) external verifyRCParams(_rcParam) onlyOwner {
        require(controlTower.isMarket(market), NotAMarketRewards());
        processRewards(market, controlTower.feeTreasury());
        rcParams[market] = _rcParam;
    }

    /**
     * @notice TODO
     * @param  market Address of the market to compute the reward cut for.
     */
    function computeRCForMarket(address market) external view returns (uint256) {
        return _calculateRC(tgUSDOracle.price(), rcParams[market]);
    }

    /**
     * @notice TODO
     * @param  tgUSDPrice Price of tgUSD in wei.
     * @param  _rcParams  Reward cut parameters of the market.
     */
    function simulateRC(uint256 tgUSDPrice, RCParams memory _rcParams) external pure returns (uint256) {
        return _calculateRC(tgUSDPrice, _rcParams);
    }

    /**
     * @notice Computes the reward cut percentage based on the tgUSD price and market parameters
     * @param  tgUSDPrice Price of tgUSD in wei.
     * @param  _rcParams   Reward cut parameters of the market.
     */
    function _calculateRC(uint256 tgUSDPrice, RCParams memory _rcParams) internal pure returns (uint256) {
        uint256 stepAmount = _rcParams.stepAmount;
        // Cut percentage is always constant
        if (stepAmount == 1) {
            return _rcParams.startCutPercentage;
        }
        // Cut percentage either startCutPercentage or endCutPercetange
        else if (stepAmount == 2) {
            if (tgUSDPrice >= uint256(_rcParams.startCutPrice) * 1e12) {
                return _rcParams.startCutPercentage;
            } else {
                return _rcParams.endCutPercentage;
            }
        }
        // Cut percentage is computed regarding the step amount
        else {
            uint256 startCutPrice = uint256(_rcParams.startCutPrice) * 1e12;
            uint256 endCutPrice = uint256(_rcParams.endCutPrice) * 1e12;
            // When tgUSDPrice is above the startCutPrice
            if (tgUSDPrice >= startCutPrice) {
                return _rcParams.startCutPercentage;
            }
            if (tgUSDPrice < endCutPrice) {
                return _rcParams.endCutPercentage;
            }
            uint256 stepsBetween = stepAmount - 2;

            //TODO What happens here if tgUSD > startCutPrice ?
            uint256 actualStep = 1 + (startCutPrice - tgUSDPrice) / ((startCutPrice - endCutPrice) / stepsBetween);
            return _rcParams.startCutPercentage + (actualStep * (_rcParams.endCutPercentage - _rcParams.startCutPercentage)) / stepsBetween;
        }
    }
}
