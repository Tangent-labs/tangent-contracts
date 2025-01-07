// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IRewards} from "../../../interfaces/internals/tgUSD/IRewards.sol";
import {ICollateral} from "../../../interfaces/internals/tgUSD/ICollateral.sol";

import {ERC20Infos, IERC20} from "../../ERC20Infos.sol";

contract HarvestUI is ERC20Infos {
    struct HarvestUIOut {
        address marketAddress;
        string collateralName;
        uint256 harvesterFeePercentage;
        ERC20Infos.ERC20Info[] tokenAmounts;
    }

    error HarvestUIOutError(HarvestUIOut[] output);

    constructor(address[] memory markets) {
        uint256 marketLength = markets.length;
        HarvestUIOut[] memory output = new HarvestUIOut[](marketLength);

        for (uint256 i; i < marketLength; ) {
            address market = markets[i];

            IERC20[] memory erc20s = IRewards(market).getRewardTokens();
            uint256 erc20sLength = erc20s.length;
            ERC20Infos.ERC20Info[] memory tokenAmounts = new ERC20Infos.ERC20Info[](erc20sLength);

            for (uint256 j; j < erc20s.length; ) {
                IERC20 rewardToken = erc20s[j];
                tokenAmounts[j] = getERC20Infos(rewardToken, rewardToken.balanceOf(market));

                unchecked {
                    ++j;
                }
            }
            output[i] = HarvestUIOut({
                marketAddress: market,
                collateralName: ICollateral(market).collatToken().symbol(),
                harvesterFeePercentage: IRewards(market).harvesterFeePercentage(),
                tokenAmounts: tokenAmounts
            });
            unchecked {
                ++i;
            }
        }
        revert HarvestUIOutError(output);
    }
}
