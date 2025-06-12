// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IMarketExternalActions, IERC20} from "../../../interfaces/internals/tgUSD/IMarketExternalActions.sol";
import {IRewardAccumulator} from "../../../interfaces/internals/tgUSD/IRewardAccumulator.sol";
contract MarketCurrentAPR {
    mapping(IERC20 => uint256) rewardPrice;

    constructor(IMarketExternalActions[] memory markets, IRewardAccumulator rewardAccumulator) {}

    // function getMarketAPRs(IMarketExternalActions[] memory markets, IRewardAccumulator rewardAccumulator) public view returns (AccountLiquidationInfo[] memory) {
    //     AccountLiquidationInfo[] memory output = new AccountLiquidationInfo[](usersMarkets.length);
    //     for (uint256 i; i < markets.length; i++) {
    //         IERC20[] memory rewardTokens = rewardAccumulator.getRewardTokens();
    //     }
    //     return output;
    // }
}
