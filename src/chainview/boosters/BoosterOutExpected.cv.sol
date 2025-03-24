// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ISdtUtilities} from "../../interfaces/internals/CVG/ISdtUtilities.sol";
import {ISdtStaking} from "../../interfaces/internals/CVG/ISdtStaking.sol";

import {IGauge} from "../../interfaces/externals/Curve/IGauge.sol";
import {ICrvPoolPlain} from "../../interfaces/externals/Curve/ICrvPoolPlain.sol";

import {IOperator} from "../../interfaces/externals/StakeDao/IOperator.sol";
import {ISdAsset} from "../../interfaces/externals/StakeDao/ISdAsset.sol";

import {AddrBooster} from "../../libs/Resources/ResourcesBooster.sol";

contract BoosterOutExpected {
    ISdtUtilities public constant SDT_UTILITIES = ISdtUtilities(0xD861Ff854206d0Db64f1C0f3108f59576A5CCc04);
    struct BoosterConvertOut {
        uint256 sdAssetAmountOut;
        uint256 feePercentage;
        uint256 feeOrIncentiveAmount;
    }

    error BoosterConvertError(BoosterConvertOut output);

    constructor(ISdtStaking staking, uint256 amountIn, bool isLock) {
        IGauge gaugeAsset = IGauge(staking.stakingAsset());
        ISdAsset sdAsset = ISdAsset(gaugeAsset.staking_token());

        ICrvPoolPlain crvPoolPlain = ICrvPoolPlain(SDT_UTILITIES.stablePoolPerAsset(address(sdAsset)));

        uint256 feeOrIncentiveAmount;
        uint256 feePercentage;
        uint256 sdAssetAmountOut;

        if (staking == AddrBooster.SD_BAL_STAKING) {
            (sdAssetAmountOut, feePercentage, feeOrIncentiveAmount) = _getDepositResult(sdAsset, amountIn, isLock);
        }
        // Nominal case, we are checking the peg
        else {
            sdAssetAmountOut = crvPoolPlain.get_dy(0, 1, amountIn);
            if (sdAssetAmountOut < amountIn) {
                (sdAssetAmountOut, feePercentage, feeOrIncentiveAmount) = _getDepositResult(sdAsset, amountIn, isLock);
            }
        }

        revert BoosterConvertError(BoosterConvertOut({sdAssetAmountOut: sdAssetAmountOut, feePercentage: feePercentage, feeOrIncentiveAmount: feeOrIncentiveAmount}));
    }

    function _getDepositResult(ISdAsset sdAsset, uint256 amountIn, bool isLock) internal view returns (uint256, uint256, uint256) {
        IOperator operator = sdAsset.operator();

        if (isLock) {
            uint256 incentiveAmount = operator.incentiveToken();
            return (amountIn + incentiveAmount, 0, incentiveAmount);
        } else {
            uint256 feePercentage;
            try operator.lockIncentive() returns (uint256 f) {
                feePercentage = f;
            } catch {
                feePercentage = operator.lockIncentivePercent();
            }
            uint256 feeAmount = (amountIn * feePercentage) / 10_000;

            return (amountIn - feeAmount, feePercentage, feeAmount);
        }
    }
}
