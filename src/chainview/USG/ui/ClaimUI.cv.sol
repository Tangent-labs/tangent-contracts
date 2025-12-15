// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICollateral} from "../../../interfaces/internals/USG/ICollateral.sol";
import {IMarketViewer} from "../../../interfaces/internals/USG/IMarketViewer.sol";
import {IRewardAccumulator} from "../../../interfaces/internals/USG/IRewardAccumulator.sol";

import {ERC20Infos, IERC20, TokenAmount, ERC20AmountInfos} from "../../ERC20Infos.sol";

contract ClaimUI is ERC20Infos {
    struct ClaimUIOut {
        address marketAddress;
        uint256 collatStakedUsdValue;
        ERC20AmountInfos collatStaked;
        ERC20AmountInfos[] claimableTokens;
    }

    error ClaimUIOutError(ClaimUIOut[] output);

    constructor(address account, address[] memory markets, IMarketViewer marketViewer) {
        ClaimUIOut[] memory output = new ClaimUIOut[](markets.length);

        for (uint256 i; i < markets.length; ) {
            address market = markets[i];
            IRewardAccumulator rewardAccumulator = IRewardAccumulator(ICollateral(market).rewardAccumulator());

            TokenAmount[] memory claimable = rewardAccumulator.claimableRewards(market, account);

            ERC20AmountInfos[] memory claimableTokens = new ERC20AmountInfos[](claimable.length);

            for (uint256 j; j < claimable.length; ) {
                claimableTokens[j] = getERC20AmountInfos(claimable[j]);
                unchecked {
                    ++j;
                }
            }

            output[i] = ClaimUIOut({
                marketAddress: market,
                collatStakedUsdValue: marketViewer.positionValue(ICollateral(market), account),
                collatStaked: getERC20AmountInfos(TokenAmount({token: ICollateral(market).collatToken(), amount: ICollateral(market).collateralBalances(account)})),
                claimableTokens: claimableTokens
            });
            unchecked {
                ++i;
            }
        }
        revert ClaimUIOutError(output);
    }
}
