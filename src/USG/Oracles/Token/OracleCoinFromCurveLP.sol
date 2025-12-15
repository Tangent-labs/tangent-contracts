// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {OracleBase} from "../OracleBase.sol";

struct OracleCoinFromCurveLPStruct {
    ICurveStableSwapNG lp;
    uint96 otherStableDecimals;
    IPriceOracle otherStableOracle;
    uint88 isParamsForPriceOracle;
    uint8 isReversed;
}
/// @title OracleCoinFromCurveLP
/// @author Tangent Finance
/// @notice Delivers reliable price oracle data for an ERC20 token, based on pricing information from a Curve pool.
contract OracleCoinFromCurveLP is OracleBase {
    OracleCoinFromCurveLPStruct public oracleParams;
    constructor(address _lp, IPriceOracle _otherStableOracle, uint8 isReversed, string memory _oracleName) OracleBase(_oracleName) {
        uint88 isParamsForPriceOracle;
        try ICurveStableSwapNG(_lp).price_oracle() {
            isParamsForPriceOracle = 0;
        } catch {
            isParamsForPriceOracle = 1;
        }
        oracleParams = OracleCoinFromCurveLPStruct({
            lp: ICurveStableSwapNG(_lp),
            otherStableOracle: _otherStableOracle,
            otherStableDecimals: _otherStableOracle.decimals(),
            isParamsForPriceOracle: isParamsForPriceOracle,
            isReversed: isReversed
        });
    }

    /**
     * @notice Returns a time weighted price of a token present in a Curve pool
     * @dev    Using the price_oracle, we can are protected from flash attacks.
     * @return The price of the token from the pool.
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        OracleCoinFromCurveLPStruct memory params = oracleParams;

        return _computePrice(params.lp, params.isParamsForPriceOracle, params.otherStableOracle.latestAnswer(isNoFailMode), params.isReversed);
    }

    /**
     * @notice Returns a time weighted price of a token present in a Curve pool
     * @dev    Using the price_oracle, we can are protected from flash attacks.
     * @return The price of the token from the pool.
     */
    function latestAnswerUpdate(bool isNoFailMode) external override returns (uint256) {
        OracleCoinFromCurveLPStruct memory params = oracleParams;

        return _computePrice(params.lp, params.isParamsForPriceOracle, params.otherStableOracle.latestAnswerUpdate(isNoFailMode), params.isReversed);
    }

    function _computePrice(ICurveStableSwapNG lp, uint88 isParamsForPriceOracle, uint256 priceOtherStable, uint8 isReversed) internal view returns (uint256) {
        uint256 p;

        // When price is reversed do 1/price to get the correct price
        if (isReversed == 1) {
            p = 1e36 / _priceOracle(lp, isParamsForPriceOracle);
        } else {
            p = _priceOracle(lp, isParamsForPriceOracle);
        }

        return (p * priceOtherStable) / 1e18;
    }

    function _priceOracle(ICurveStableSwapNG lp, uint128 isParamsForPriceOracle) internal view returns (uint256) {
        if (isParamsForPriceOracle != 0) {
            return lp.price_oracle(0);
        } else {
            return lp.price_oracle();
        }
    }
}
