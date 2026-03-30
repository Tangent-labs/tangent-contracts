// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {LightReentrancyGuardTransient} from "../Utilities/abstract/LightReentrancyGuardTransient.sol";

import {LightOwnable} from "../Utilities/abstract/LightOwnable.sol";
import {ICollateral} from "../../interfaces/internals/USG/ICollateral.sol";
import {IRewardAccumulator, RCParams, Reward, TokenAmount} from "../../interfaces/internals/USG/IRewardAccumulator.sol";
import {IAggregatorStablePriceV3} from "../../interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";
import {IMarketExternalActions} from "../../interfaces/internals/USG/IMarketExternalActions.sol";

import {IControlTower} from "../../interfaces/internals/USG/IControlTower.sol";

/// @title RewardAccumulator
/// @author Tangent Finance
/// @notice Manages processing, streaming and claiming of the rewards.
contract RewardAccumulator is IRewardAccumulator, LightOwnable, LightReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    uint256 public constant DENOMINATOR = 100_000;

    /// @dev Duration that rewards are streamed over
    uint256 public constant REWARDS_DURATION = 7 days; // 1 week

    IControlTower public controlTower;

    IAggregatorStablePriceV3 public USGOracle;

    /// @notice Addresses whitelisted that can claim and process rewards on this contract
    mapping(address => bool) public isMarket;

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
    event AddReward(address market, IERC20 reward);
    event RemoveReward(address market, address reward);
    event SetRCParams(address market, RCParams rcParams);

    error NoRewardsToClaimFromContract(address contractAddr);
    error IncorrectRewardLength(uint256 rewardLengthInParam, uint256 realRewardLength);
    error NoRewardToMultiClaim();
    error NoRewardToSimpleClaim();
    error NotAMarketRewards();

    error HarvesterFeeTooHigh();
    error NothingToProcess();
    error RewardAlreadyAdded(IERC20 erc20);

    error CallerNotMarketCreator(address caller);

    error StepAmountZero();
    error StartCutPriceTooHigh();
    error StartCutPercentageBiggerThanEnd();
    error StartCutPriceSmallerThanEnd();
    error EndCutPercentageBiggerThan100();
    error StartCutPercentageBiggerThan100();

    function _verifyRCParams(RCParams calldata _rcParam) internal pure {
        require(_rcParam.stepAmount != 0, StepAmountZero());
        // Harvest Fee <= 2%
        require(_rcParam.harvestFeePercentage <= 2_000, HarvesterFeeTooHigh());
        // Start of the cut must be <= 1$
        require(_rcParam.startCutPrice <= 1_000_000, StartCutPriceTooHigh());
        // Maximum reward cut cannot be more than 100%
        require(DENOMINATOR >= _rcParam.endCutPercentage, EndCutPercentageBiggerThan100());
        // Minimum reward cut cannot be more than 100%
        require(DENOMINATOR >= _rcParam.startCutPercentage, StartCutPercentageBiggerThan100());

        // When there is at least 1 step
        if (_rcParam.stepAmount != 1) {
            // Minimum reward cut should be < Maximum reward cut
            require(_rcParam.startCutPercentage < _rcParam.endCutPercentage, StartCutPercentageBiggerThanEnd());

            // When there are 2 steps and more
            if (_rcParam.stepAmount != 2) {
                // Price where the cut starts must be > start when the cut is the highest
                require(_rcParam.startCutPrice > _rcParam.endCutPrice, StartCutPriceSmallerThanEnd());
            }
        }
    }

    constructor(address _owner, IControlTower _controlTower, IAggregatorStablePriceV3 _USGOracle) {
        controlTower = _controlTower;
        USGOracle = _USGOracle;

        _transferOwnership(_owner);
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
        require(isMarket[msg.sender], NotAMarketRewards());
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
    function claimSimple(address market) external nonReentrant {
        require(isMarket[market], NotAMarketRewards());

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
     *  @notice Claim rewards of caller on several markets.
     *  @param markets Array of markets to claim the rewards on
     *  @param rewardLength Amount of different tokens to claim as a reward. Will fail if not setup properly.
     *                      Ex : Market A has CRV and CVX and Market B has FXN, hence the rewardLength is 3.
     */
    function claimMultiple(address[] calldata markets, uint256 rewardLength) external nonReentrant {
        // We save this length on his own variable, to not miss with the assembly manipulations
        uint256 marketsLen = markets.length;
        // Initialize the final merged array containing the totals of rewards
        TokenAmount[] memory totals = new TokenAmount[](rewardLength);
        uint256 actualErc20Index;

        // Iterates through all of the markets to claim rewards
        for (uint256 marketIndex; marketIndex < marketsLen; ) {
            address market = markets[marketIndex];

            // Reverts if one of the market passed in parameter is not one.
            // It protects us agains a malicious user input.
            require(isMarket[market], NotAMarketRewards());

            // Get and update the amount of rewards to claim
            TokenAmount[] memory tokenAmountsToClaim = _claimRewards(market, msg.sender);
            // If the rewards returned by the gUSD is an empty array,
            require(tokenAmountsToClaim.length != 0, NoRewardsToClaimFromContract(address(market)));
            // Iterates over all erc20 received from the claim on the gUSD
            for (uint256 tokenIndex; tokenIndex < tokenAmountsToClaim.length; ) {
                IERC20 rewardToken = tokenAmountsToClaim[tokenIndex].token;
                // If token is seen the first time (tokensToClaim[token] == 0)
                uint256 index = _tLoadUintForAddress(address(rewardToken));

                // If the index is known, we find it in the totals array and increment it.
                if (index != 0) {
                    totals[index - 1].amount += tokenAmountsToClaim[tokenIndex].amount;
                }
                // Else, the index is not known;
                else {
                    // we create the entry in totals;
                    totals[actualErc20Index++] = TokenAmount({token: rewardToken, amount: tokenAmountsToClaim[tokenIndex].amount});
                    // we create a transient entry linking the index of the new reward token in the totals array.
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
        for (uint256 i; i < totals.length; ) {
            IERC20 token = totals[i].token;
            uint256 amount = totals[i].amount;
            // If only there are rewards to distribute we transfer reward tokens to the positions owner
            if (amount != 0) {
                token.safeTransfer(msg.sender, amount);
            }
            // Erase transient for the token
            _tStoreUintForAddress(address(token), 0);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Updates all rewards for the user and returns the amount of rewards to claim
     * @param market  Market address to claim rewards from
     * @param account Address to claim rewards for
     */
    function _claimRewards(address market, address account) internal returns (TokenAmount[] memory) {
        (uint256 collateralBalance, uint256 totalCollateral) = ICollateral(market).getBalanceAndTotalCollateral(account);
        _updateReward(market, account, collateralBalance, totalCollateral);

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
     * @param tokens array of token to claim
     */
    function claimCutFees(IERC20[] memory tokens) external nonReentrant {
        address _feeTreasury = controlTower.feeTreasury();
        for (uint256 erc20Id; erc20Id < tokens.length; ) {
            IERC20 token = tokens[erc20Id];
            token.safeTransfer(_feeTreasury, cutFeeForToken[token]);

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
     * @notice Add some new reward tokens to the stream of a market
     * @param market          Address of the market to set the new rewards for
     * @param newRewardTokens Addresses of the new reward tokens streamed on the market
     */
    function addNewRewards(address market, IERC20[] calldata newRewardTokens) public onlyOwner {
        _addRewards(market, newRewardTokens);
    }

    function _addRewards(address market, IERC20[] calldata newRewardTokens) internal {
        for (uint256 i; i < newRewardTokens.length; ) {
            IERC20 _newRewardToken = newRewardTokens[i];
            /// If lastUpdateTime is equal to 0, it means the token is not already added as a reward
            require(rewardData[market][_newRewardToken].lastUpdateTime == 0, RewardAlreadyAdded(_newRewardToken));

            rewardTokens[market].push(_newRewardToken);
            rewardData[market][_newRewardToken].lastUpdateTime = uint128(block.timestamp);
            rewardData[market][_newRewardToken].periodFinish = uint128(block.timestamp);
            unchecked {
                ++i;
            }
            emit AddReward(market, _newRewardToken);
        }
    }

    /**
     * @notice Remove a reward associated to a market
     * @dev    This should be called ONLY if a reward token is not transferable anymore, blocking actions on a specific market.
     * @param market          Address of the market where the reward token will be removed
     * @param tokenToRemove   Address of the reward token to remove
     */
    function removeReward(address market, address tokenToRemove) external onlyOwner {
        IERC20[] storage tokens = rewardTokens[market];
        uint256 length = tokens.length;

        for (uint256 i; i < length; i++) {
            if (address(tokens[i]) == tokenToRemove) {
                tokens[i] = tokens[length - 1];
                tokens.pop();
                emit RemoveReward(market, tokenToRemove);
                break;
            }
        }
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

    /**
     * @notice Start the streaming of the reward to the stakers of a market.
     * @param market             Market to process the rewards for
     * @param harvestFeeReceiver Receiver of the harvester fee
     */
    function processRewards(address market, address harvestFeeReceiver) public nonReentrant {
        require(isMarket[market], NotAMarketRewards());
        // Checkpoint the rewards
        _updateReward(market, address(0), 0, ICollateral(market).totalCollateral());

        // Claim the rewards linked to the collateral from the underlying protocol
        TokenAmount[] memory rewardAmounts = IMarketExternalActions(market).claimUnderlyingRewards(rewardTokens[market]);
        uint256 rewardTokensLength = rewardAmounts.length;
        uint256 rewardCutPercentage = lastRewardCuts[market];

        RCParams memory _rcParams = rcParams[market];

        // Computes and actulize the new reward cut
        lastRewardCuts[market] = _calculateRC(USGOracle.price_w(), _rcParams);

        uint16 harvestFeePercentage = _rcParams.harvestFeePercentage;

        // Stream rewards for every tokens
        for (uint256 tokenIndex; tokenIndex < rewardTokensLength; ) {
            IERC20 rewardToken = rewardAmounts[tokenIndex].token;
            // Update streaming data for the current rewardToken
            (uint256 rewardCutAmount, uint256 harvesterAmount, uint256 dusts) = _processRewards(
                market,
                rewardToken,
                rewardAmounts[tokenIndex].amount,
                harvestFeePercentage,
                rewardCutPercentage
            );
            // If there are cut rewards, increments it
            if (rewardCutAmount != 0) {
                cutFeeForToken[rewardToken] += rewardCutAmount;
            }
            // If there are harvest rewards, transfer them to the harvest fee receiver
            if (harvesterAmount != 0) {
                rewardToken.safeTransfer(harvestFeeReceiver, harvesterAmount);
            }

            // Transfer back the dusts for next processes
            // Gas is not expensives because balanceOf slots of the Market and RewardAccumulator are still hot
            if (dusts != 0) {
                rewardToken.safeTransfer(market, dusts);
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
    /**
     * @notice Start the streaming of the reward to the stakers of several markets at the same time.
     * @dev    This method optimize the gas cost of the reward processing by updating only once per reward token
     *         the
     * @param markets            Markets to process the rewards for
     * @param harvestFeeReceiver Receiver of the harvester fee
     * @param rewardLength       Amount of different tokens that will be processed. Will fail if not setup properly.
     *                           Ex : Market A has CRV and CVX and Market B has FXN, hence the rewardLength is 3.
     */
    function processMultiRewards(address[] calldata markets, address harvestFeeReceiver, uint256 rewardLength) external nonReentrant {
        // Retrive only once the usg price
        uint256 USGPrice = USGOracle.price_w();

        // Final array containing the accumulated cutFees and harvesterFee for all reward tokens.
        ProcessableRewards[] memory processables = new ProcessableRewards[](rewardLength);
        uint256 actualErc20Index;

        // For every markets
        for (uint256 i; i < markets.length; ) {
            address market = markets[i];

            // Reverts if one of the market passed in parameter is not one.
            // It protects us agains a malicious user input.
            require(isMarket[market], NotAMarketRewards());
            // Checkpoint the rewards
            _updateReward(market, address(0), 0, ICollateral(market).totalCollateral());
            // Claim the rewards linked to the collateral from the underlying protocol
            TokenAmount[] memory rewardAmounts = IMarketExternalActions(market).claimUnderlyingRewards(rewardTokens[market]);
            uint256 rewardTokensLength = rewardAmounts.length;

            uint256 rewardCutPercentage = lastRewardCuts[market];
            RCParams memory _rcParams = rcParams[market];

            // Actualize reward cut
            lastRewardCuts[market] = _calculateRC(USGPrice, _rcParams);

            // For every reward token of the market
            for (uint256 j; j < rewardTokensLength; ) {
                IERC20 rewardToken = rewardAmounts[j].token;

                // Update streaming data for the current rewardToken
                (uint256 rewardCutAmount, uint256 harvesterAmount, uint256 dusts) = _processRewards(
                    market,
                    rewardToken,
                    rewardAmounts[j].amount,
                    _rcParams.harvestFeePercentage,
                    rewardCutPercentage
                );

                // If token is seen the first time (tokensToClaim[token] == 0)
                uint256 index = _tLoadUintForAddress(address(rewardToken));

                // If the reward token e
                if (index != 0) {
                    processables[index - 1].amountForFees += rewardCutAmount;
                    processables[index - 1].amountForHarvester += harvesterAmount;
                }
                // First time the token is iterated
                else {
                    processables[actualErc20Index++] = ProcessableRewards({rewardToken: rewardToken, amountForFees: rewardCutAmount, amountForHarvester: harvesterAmount});
                    _tStoreUintForAddress(address(rewardToken), actualErc20Index);
                }

                // Transfer back the dusts for next processes
                // Gas is not expensives because balanceOf slots of the Market and RewardAccumulator are still hot
                if (dusts != 0) {
                    rewardToken.safeTransfer(market, dusts);
                }

                unchecked {
                    ++j;
                }
            }

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
    ) internal returns (uint256, uint256, uint256) {
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

        uint256 adjustedRewardAmount;
        uint256 dusts;
        if (block.timestamp >= rData.periodFinish) {
            dusts = rewardAmountStreamed % REWARDS_DURATION;
            adjustedRewardAmount = rewardAmountStreamed - dusts;
        } else {
            uint256 newRewardAmountStreamed = (rewardAmountStreamed + (rData.periodFinish - block.timestamp) * rData.rewardRate);
            dusts = newRewardAmountStreamed % REWARDS_DURATION;
            adjustedRewardAmount = newRewardAmountStreamed - dusts;
        }
        rData.rewardRate = adjustedRewardAmount / REWARDS_DURATION;
        rData.lastUpdateTime = uint128(block.timestamp);
        rData.periodFinish = uint128(block.timestamp + REWARDS_DURATION);

        // Treat case where rewardAmountStreamed is lower than dusts
        emit RewardNotified(market, rewardToken, rewardAmountStreamed > dusts ? rewardAmountStreamed - dusts : 0, harvesterFees, rewardCutAmount);

        return (rewardCutAmount, harvesterFees, dusts);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       REWARD CUT
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function initializeMarket(address market, IERC20[] calldata _rewardTokens, RCParams calldata _rcParam) external {
        _verifyRCParams(_rcParam);
        require(controlTower.isMarketCreator(msg.sender), CallerNotMarketCreator(msg.sender));
        lastRewardCuts[market] = _calculateRC(USGOracle.price_w(), _rcParam);
        rcParams[market] = _rcParam;
        _addRewards(market, _rewardTokens);
        isMarket[market] = true;
    }

    /**
     * @notice Updates the RC params of a market
     * @param  market   Address of the market to compute the new reward cut for.
     * @param  _rcParam New RC params to apply to a market
     */
    function updateRCParams(address market, RCParams calldata _rcParam) external onlyOwner {
        // Verify if the new reward cut params are compliant
        _verifyRCParams(_rcParam);
        // Update the new RC Params
        rcParams[market] = _rcParam;
        // Process the rewards with the old RC params
        processRewards(market, controlTower.feeTreasury());
        emit SetRCParams(market, _rcParam);
    }

    /**
     * @notice Computes and returns the next reward cut of a market without storing it.
     * @param  market Address of the market to compute the new reward cut for.
     */
    function computeRCForMarket(address market) external view returns (uint256) {
        return _calculateRC(USGOracle.price(), rcParams[market]);
    }

    /**
     * @notice Compute a reward cut with a given USG Price and some reward cut params
     * @param  USGPrice   Price of USG in wei.
     * @param  _rcParams  Reward cut parameters.
     */
    function simulateRC(uint256 USGPrice, RCParams memory _rcParams) external pure returns (uint256) {
        return _calculateRC(USGPrice, _rcParams);
    }

    /**
     * @notice Computes the reward cut percentage based on the USG price and market parameters
     * @param  USGPrice Price of USG in wei.
     * @param  _rcParams   Reward cut parameters of the market.
     */
    function _calculateRC(uint256 USGPrice, RCParams memory _rcParams) internal pure returns (uint256) {
        uint256 stepAmount = _rcParams.stepAmount;
        // Cut percentage is always constant
        if (stepAmount == 1) {
            return _rcParams.startCutPercentage;
        }
        // Cut percentage either startCutPercentage or endCutPercetange
        else if (stepAmount == 2) {
            if (USGPrice >= uint256(_rcParams.startCutPrice) * 1e12) {
                return _rcParams.startCutPercentage;
            } else {
                return _rcParams.endCutPercentage;
            }
        }
        // Cut percentage is computed regarding the step amount
        else {
            uint256 startCutPrice = uint256(_rcParams.startCutPrice) * 1e12;
            uint256 endCutPrice = uint256(_rcParams.endCutPrice) * 1e12;
            // When the current price of USG is over the start cut price, the minimum Reward cut is applied
            if (USGPrice >= startCutPrice) {
                return _rcParams.startCutPercentage;
            }
            // When the current price of USG is lower than the end cut price, the maximum Reward cut is applied
            if (USGPrice <= endCutPrice) {
                return _rcParams.endCutPercentage;
            }
            // Compute the actual step regarding the current price of USG
            uint256 actualStep = 1 + ((stepAmount - 2) * (startCutPrice - USGPrice)) / (startCutPrice - endCutPrice);
            // Compute the percentage amount increased by one step and multiply it by the actual step to get the percentage amount to increment to the startPercentage.
            return _rcParams.startCutPercentage + (actualStep * (_rcParams.endCutPercentage - _rcParams.startCutPercentage)) / (stepAmount - 1);
        }
    }
}
