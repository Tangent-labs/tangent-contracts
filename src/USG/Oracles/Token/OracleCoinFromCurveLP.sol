// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {OracleBase} from "../OracleBase.sol";

struct OracleCoinFromCurveLPStruct {
    ICurveStableSwapNG lp;
    IPriceOracle otherStableOracle;
    uint128 otherStableDecimals;
    uint128 isParamsForPriceOracle;
    bool isReversed;
}
/// @title OracleCoinFromCurveLP
/// @notice This contract provides price oracle functionality for an ERC20, from a pool of Curve
contract OracleCoinFromCurveLP is OracleBase {
    OracleCoinFromCurveLPStruct public oracleParams;
    constructor(address _lp, IPriceOracle _otherStableOracle, bool isReversed) {
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

        uint256 priceOtherStable = params.otherStableOracle.latestAnswer(isNoFailMode);

        uint256 priceOracle = params.isReversed ? 1e36 / _priceOracle(params.lp, params.isParamsForPriceOracle) : _priceOracle(params.lp, params.isParamsForPriceOracle);

        return (priceOracle * priceOtherStable) / 1e18;
    }

    function _priceOracle(ICurveStableSwapNG lp, uint128 isParamsForPriceOracle) internal view returns (uint256) {
        if (isParamsForPriceOracle != 0) {
            return lp.price_oracle(0);
        } else {
            return lp.price_oracle();
        }
    }
}
