// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ISdtUtilities} from "../../interfaces/internals/CVG/ISdtUtilities.sol";
import {ISdtStaking} from "../../interfaces/internals/CVG/ISdtStaking.sol";
import {ICommonStruct} from "../../interfaces/internals/ICommonStruct.sol";

import {IGauge} from "../../interfaces/externals/Curve/IGauge.sol";
import {ICrvPoolPlain} from "../../interfaces/externals/Curve/ICrvPoolPlain.sol";

import {IOperator} from "../../interfaces/externals/StakeDao/IOperator.sol";
import {ISdAsset} from "../../interfaces/externals/StakeDao/ISdAsset.sol";

import {AddrBooster} from "../../libs/resources/ResourcesBooster.sol";

contract CvgCvxOutExpected {
    ICrvPoolPlain cvgCVX1Lp = ICrvPoolPlain(0xc50E191F703FB3160fC15d8b168A8c740fec3666);

    struct CvgCvxConvertOutput {
        uint256 amountOut;
        uint256 feePercentage;
        uint256 feeAmount;
    }

    enum CvgCvxTokens {
        ETH,
        CVX,
        CVX1,
        CVG_CVX
    }

    error BoosterConvertError(CvgCvxConvertOutput cvgSdtOut);

    constructor(uint256 amountIn, CvgCvxTokens inType, CvgCvxTokens outType, bool isSwap, bool isLock) {
        uint256 amountOut = amountIn;
        uint256 feePercentage;
        uint256 feeAmount;

        if (inType == CvgCvxTokens.ETH) {
            amountIn = _convertEthToCvx(amountIn);
            (amountOut, feePercentage, feeAmount) = _convertCvxToCvgCvx(amountIn, isSwap, isLock);
        }
        // CVX or CVX1 in
        else if (inType == CvgCvxTokens.CVX || inType == CvgCvxTokens.CVX1) {
            if (outType == CvgCvxTokens.CVG_CVX) {
                (amountOut, feePercentage, feeAmount) = _convertCvxToCvgCvx(amountIn, isSwap, isLock);
            }
        }
        // cvgCVX in
        else {
            amountOut = cvgCVX1Lp.get_dy(1, 0, amountIn);
        }

        revert BoosterConvertError(CvgCvxConvertOutput({amountOut: amountOut, feePercentage: feePercentage, feeAmount: feeAmount}));
    }

    function _convertCvxToCvgCvx(uint256 amountIn, bool isSwap, bool isLock) public view returns (uint256 amountOut, uint256 feePercentage, uint256 feeAmount) {
        if (isSwap) {
            amountOut = cvgCVX1Lp.get_dy(1, 0, amountIn);
        } else {
            if (!isLock) {
                feePercentage = AddrBooster.CVG_CVX.mintFees();
                feeAmount = (amountIn * AddrBooster.CVG_CVX.mintFees()) / 100_000;
                amountOut = amountIn - feeAmount;
            }
        }
    }

    function _convertEthToCvx(uint256 amountIn) public view returns (uint256 amountCvxOut) {
        (, address poolCurve, , , uint48 indexEth, uint48 indexAsset) = AddrBooster.CVG_CVX_STAKING.poolEthInfo();

        return ICrvPoolPlain(poolCurve).get_dy(int128(uint128(indexEth)), int128(uint128(indexAsset)), amountIn);
    }
}
