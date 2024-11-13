// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ISdtUtilities} from "../../interfaces/internals/CVG/ISdtUtilities.sol";
import {ISdtStaking} from "../../interfaces/internals/CVG/ISdtStaking.sol";
import {ICommonStruct} from "../../interfaces/internals/ICommonStruct.sol";

import {IGauge} from "../../interfaces/externals/Curve/IGauge.sol";
import {ICrvPoolPlain} from "../../interfaces/externals/Curve/ICrvPoolPlain.sol";

import {IOperator} from "../../interfaces/externals/StakeDao/IOperator.sol";
import {ISdAsset} from "../../interfaces/externals/StakeDao/ISdAsset.sol";

import {AddrBooster} from "../../libs/Resources/ResourcesBooster.sol";

contract CvgSdtOutExpected {
    ISdtUtilities public constant SDT_UTILITIES = ISdtUtilities(0xD861Ff854206d0Db64f1C0f3108f59576A5CCc04);
    struct BoosterConvertOut {
        uint256 sdAssetAmountOut;
        uint256 feePercentage;
        uint256 feeOrIncentiveAmount;
    }

    error BoosterConvertError(uint256 cvgSdtOut);

    constructor(uint256 sdtAmountIn) {
        ICrvPoolPlain crvPoolPlain = ICrvPoolPlain(0xC6628f00F29cc89a87BBeE7554C4725611200fD7);

        uint256 cvgSdtAmountOut = crvPoolPlain.get_dy(0, 1, sdtAmountIn);

        if (cvgSdtAmountOut < (sdtAmountIn * SDT_UTILITIES.percentageDepeg()) / 100) {
            cvgSdtAmountOut = sdtAmountIn;
        }

        revert BoosterConvertError(cvgSdtAmountOut);
    }
}
