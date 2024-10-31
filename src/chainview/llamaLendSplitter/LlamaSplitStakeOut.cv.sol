// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ISplitterToken} from "../../interfaces/internals/LendSplitter/ISplitterToken.sol";
import {ILendRewardSplitter, ILlamaVault, IgUSDCvx, ISplitterTokenComp} from "../../interfaces/internals/LendSplitter/ILendRewardSplitter.sol";
import {ICurveRouter} from "../../interfaces/externals/Curve/ICurveRouter.sol";

contract LlamaSplitStakeOut {
    ICurveRouter public constant CURVE_ROUTER = ICurveRouter(0x16C6521Dff6baB339122a0FE25a9116693265353);
    struct Zap {
        address[11] routes;
        address[5] pools;
        uint256[5][5] swapParams;
    }
    struct LendSplitterOutConverted {
        uint256 llamaVaultAmountDeposited;
        uint256 usdTokenMinted;
        uint256 autoCompoundMinted;
        uint256 feePercentage;
        uint256 feeOrIncentiveAmount;
    }

    error LendSplitterConvertError(LendSplitterOutConverted out);

    constructor(
        ILendRewardSplitter lendRewardSplitter,
        ISplitterToken splitterToken,
        uint256 amountIn,
        ILendRewardSplitter.CVX_TOKEN_TYPE inType,
        bool isAutoCompound,
        bool isStake,
        Zap memory zap
    ) {
        ILlamaVault llamaVault = splitterToken.llamaVault();
        IgUSDCvx gUSD = lendRewardSplitter.gUSDPerLlamaVault(llamaVault);
        bool isGUSD = splitterToken == gUSD;

        uint256 llamaVaultAmountDeposited;
        uint256 autoCompoundMinted;
        uint256 feePercentage;
        uint256 feeOrIncentiveAmount;

        if (zap.routes[0] != address(0)) {
            amountIn = CURVE_ROUTER.get_dy(zap.routes, zap.swapParams, amountIn, zap.pools);
        }

        if (inType == ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset) {
            amountIn = llamaVault.convertToShares(amountIn);
        }

        if (isStake) {
            feeOrIncentiveAmount = gUSD.socFeePending();
            llamaVaultAmountDeposited = amountIn + gUSD.socFeePending();
        } else {
            feePercentage = gUSD.socFeePercentage();
            feeOrIncentiveAmount = (feePercentage * amountIn) / 100_000;
            llamaVaultAmountDeposited = amountIn - feeOrIncentiveAmount;
        }
        uint256 usdTokenMinted = llamaVaultAmountDeposited;
        if (isGUSD) {
            usdTokenMinted = llamaVault.convertToAssets(llamaVaultAmountDeposited);
        }

        if (!isGUSD) {
            if (isAutoCompound) {
                autoCompoundMinted = lendRewardSplitter.scvUSDAutoCompoundPerLlamaVault(llamaVault).convertToShares(usdTokenMinted);
            }
        }

        revert LendSplitterConvertError(
            LendSplitterOutConverted({
                llamaVaultAmountDeposited: llamaVaultAmountDeposited,
                usdTokenMinted: usdTokenMinted,
                autoCompoundMinted: autoCompoundMinted,
                feePercentage: feePercentage,
                feeOrIncentiveAmount: feeOrIncentiveAmount
            })
        );
    }
}
