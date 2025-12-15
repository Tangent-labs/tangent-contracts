// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenAmount, IERC20} from "../ICommonStruct.sol";

struct Reward {
    uint128 lastUpdateTime;
    uint128 periodFinish;
    uint256 rewardRate;
    uint256 rewardPerTokenStored;
}
struct RCParams {
    uint16 harvestFeePercentage;
    /// @dev Amount of distincts reward cut steps.
    uint16 stepAmount;
    /// @dev Percentage minimum of the reward cut.
    uint32 startCutPercentage;
    /// @dev Percentage maximum of the reward cut.
    uint32 endCutPercentage;
    /// @dev Price of USG on which the reward cut starts to increase.
    uint80 startCutPrice;
    /// @dev Price of USG on which the reward cut is at its maximum
    uint80 endCutPrice;
}
interface IRewardAccumulator {
    function cutFeeForToken(IERC20 token) external view returns (uint256);

    function getRewardData(address market, IERC20 token) external view returns (Reward memory);

    function updateRewards(address account, uint256 collateralBalances, uint256 totalCollateral) external;

    function processRewards(address market, address harvestFeeReceiver) external;

    function getRewardTokens(address markets) external view returns (IERC20[] memory);

    function lastRewardCuts(address market) external view returns (uint256);

    function claimableRewards(address market, address _account) external view returns (TokenAmount[] memory userRewards);

    function simulateRC(uint256 USGPrice, RCParams calldata rcParams) external pure returns (uint256);

    function computeRCForMarket(address market) external returns (uint256);

    function initializeMarket(address market, IERC20[] calldata rewardTokens, RCParams calldata _rcParams) external;

    function getRCParams(address markets) external view returns (RCParams memory);
}
