// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IRewardAccumulator} from "../../../interfaces/internals/tgUSD/IRewardAccumulator.sol";
import {ICollateral} from "../../../interfaces/internals/tgUSD/ICollateral.sol";

import {ERC20Infos, IERC20, TokenAmount, ERC20Infos, ERC20AmountInfos} from "../../ERC20Infos.sol";

contract HarvestUI is ERC20Infos {
    struct HarvestUIOut {
        address marketAddress;
        string collateralName;
        uint256 harvesterFeePercentage;
        uint256 lastHarvestDate;
        ERC20AmountInfos[] tokenAmounts;
    }

    error HarvestUIOutError(HarvestUIOut[] output);

    constructor(address[] memory markets, IRewardAccumulator rewardAccumulator) {
        uint256 marketLength = markets.length;
        HarvestUIOut[] memory output = new HarvestUIOut[](marketLength);

        for (uint256 i; i < marketLength; ) {
            address market = markets[i];

            IERC20[] memory erc20s = rewardAccumulator.getRewardTokens(market);
            uint256 erc20sLength = erc20s.length;
            ERC20AmountInfos[] memory tokenAmounts = new ERC20AmountInfos[](erc20sLength);
            uint256 lastPeriodFinish;

            for (uint256 j; j < erc20s.length; ) {
                IERC20 rewardToken = erc20s[j];
                (, uint128 lastFinish, , ) = rewardAccumulator.rewardData(market, rewardToken);
                lastPeriodFinish = lastPeriodFinish < lastFinish ? lastFinish : lastPeriodFinish;
                tokenAmounts[j] = getERC20AmountInfos(TokenAmount({token: rewardToken, amount: rewardToken.balanceOf(market)}));

                unchecked {
                    ++j;
                }
            }
            output[i] = HarvestUIOut({
                marketAddress: market,
                collateralName: ICollateral(market).collatToken().symbol(),
                harvesterFeePercentage: rewardAccumulator.harvesterFeePercentage(market),
                lastHarvestDate: lastPeriodFinish - 7 days,
                tokenAmounts: tokenAmounts
            });
            unchecked {
                ++i;
            }
        }
        revert HarvestUIOutError(output);
    }
}
