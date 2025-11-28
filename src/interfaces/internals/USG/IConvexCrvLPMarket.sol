// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {GlobalMarketInitParams, MarketInit} from "./IMarketCore.sol";
import {ICvxRewardToken} from "../../externals/Convex/ICvxRewardToken.sol";
interface IConvexCrvLPMarket {
    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit, uint256 _pid) external;

    function cvxRewardToken() external view returns (ICvxRewardToken);
}
