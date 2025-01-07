// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IMarketCore, IERC20Metadata, IRewardAccumulator} from "./IMarketCore.sol";
import {ICvxRewardToken} from "../../externals/Convex/ICvxRewardToken.sol";
interface IConvexCrvLPMarket is IMarketCore {
    function initialize(
        MarketConstants memory _marketConstants,
        MarketInit memory _marketInit,
        ICvxRewardToken _cvxRewardToken,
        uint256 _pid,
        uint256 _socFeePercentage
    ) external;
}
