// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {GlobalMarketInitParams, MarketInit} from "./IMarketCore.sol";
import {IStakingProxyERC20} from "../../externals/Convex/IStakingProxyERC20.sol";
interface IConvexFxnLPMarket {
    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit, uint256 _pid) external;

    function stakingProxyVault() external view returns (IStakingProxyERC20);
}
