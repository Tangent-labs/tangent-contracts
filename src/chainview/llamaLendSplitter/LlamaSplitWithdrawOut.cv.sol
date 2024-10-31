// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ISplitterToken} from "../../interfaces/internals/LendSplitter/ISplitterToken.sol";
import {ILendRewardSplitter, ILlamaVault, IgUSDCvx, ISplitterTokenComp} from "../../interfaces/internals/LendSplitter/ILendRewardSplitter.sol";

contract LlamaSplitWithdrawOut {
    error LendSplitterWithdrawError(uint256 out);

    constructor(
        ILendRewardSplitter lendRewardSplitter,
        ISplitterToken splitterToken,
        uint256 amountToWithdraw,
        ILendRewardSplitter.CVX_TOKEN_TYPE receivedType,
        bool isAutoCompound
    ) {
        ILlamaVault llamaVault = splitterToken.llamaVault();
        IgUSDCvx gUSD = lendRewardSplitter.gUSDPerLlamaVault(llamaVault);
        bool isGUSD = splitterToken == gUSD;

        uint256 amountOut;

        if (!isGUSD) {
            if (isAutoCompound) {
                amountToWithdraw = lendRewardSplitter.scvUSDAutoCompoundPerLlamaVault(llamaVault).convertToAssets(amountToWithdraw);
            }
        }

        if (isGUSD) {
            amountOut = llamaVault.convertToShares(amountToWithdraw);
        }

        if (receivedType == ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset) {
            amountOut = llamaVault.convertToAssets(amountOut);
        }

        revert LendSplitterWithdrawError(amountOut);
    }
}
