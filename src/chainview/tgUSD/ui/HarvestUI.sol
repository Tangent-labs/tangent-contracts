// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IRewards, IERC20} from "../../../interfaces/internals/tgUSD/IRewards.sol";
import {ICommonStruct} from "../../../interfaces/internals/ICommonStruct.sol";

contract HarvestUI {
    struct HarvestUIOut {
        address market;
        ICommonStruct.TokenAmount[] tokenAmounts;
    }

    error HarvestUIOutError(HarvestUIOut[] output);

    constructor(address[] memory markets) {
        uint256 marketLength = markets.length;
        HarvestUIOut[] memory output = new HarvestUIOut[](marketLength);

        for (uint256 i; i < marketLength; ) {
            address market = markets[i];

            IERC20[] memory erc20s = IRewards(market).getRewardTokens();
            uint256 erc20sLength = erc20s.length;
            ICommonStruct.TokenAmount[] memory tokenAmounts = new ICommonStruct.TokenAmount[](erc20sLength);

            for (uint256 j; j < erc20s.length; ) {
                IERC20 rewardToken = erc20s[j];
                tokenAmounts[j] = ICommonStruct.TokenAmount({token: rewardToken, amount: rewardToken.balanceOf(market)});

                unchecked {
                    ++j;
                }
            }
            output[i] = HarvestUIOut({market: market, tokenAmounts: tokenAmounts});
            unchecked {
                ++i;
            }
        }
        revert HarvestUIOutError(output);
    }
}
