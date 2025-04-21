// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../../interfaces/internals/tgUSD/IPriceOracle.sol";
import "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";
import "forge-std/console.sol";

struct OracleCoinFromCurveLPStruct {
    ICurveStableSwapNG lp;
    IPriceOracle otherStableOracle;
    uint128 otherStableDecimals;
    uint128 isParamsForPriceOracle;
}

contract OracleCoinFromCurveLP is IPriceOracle {
    OracleCoinFromCurveLPStruct public oracleParams;
    constructor(address _lp, IPriceOracle _otherStableOracle) {
        uint128 isParamsForPriceOracle;
        try ICurveStableSwapNG(_lp).price_oracle() {
            isParamsForPriceOracle = 0;
        } catch {
            isParamsForPriceOracle = 1;
        }

        oracleParams = OracleCoinFromCurveLPStruct({
            lp: ICurveStableSwapNG(_lp),
            otherStableOracle: _otherStableOracle,
            otherStableDecimals: _otherStableOracle.decimals(),
            isParamsForPriceOracle: isParamsForPriceOracle
        });
    }

    function latestAnswer() external view returns (uint256) {
        OracleCoinFromCurveLPStruct memory params = oracleParams;

        uint256 priceOtherStable = params.otherStableOracle.latestAnswer() * 10 ** (18 - params.otherStableDecimals);
        return (_priceOracle(params.lp, params.isParamsForPriceOracle) * priceOtherStable) / 1 ether;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function _priceOracle(ICurveStableSwapNG lp, uint128 isParamsForPriceOracle) internal view returns (uint256) {
        if (isParamsForPriceOracle != 0) {
            return lp.price_oracle(0);
        } else {
            return lp.price_oracle();
        }
    }
}
