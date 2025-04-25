// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IPriceOracle} from "../../../interfaces/internals/tgUSD/IPriceOracle.sol";
import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {IAggregatorV3} from "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";

import "forge-std/console.sol";

struct OracleCoinFromCurveLPStruct {
    ICurveStableSwapNG lp;
    IPriceOracle otherStableOracle;
    uint128 otherStableDecimals;
    uint128 isParamsForPriceOracle;
    bool isReversed;
}

contract OracleCoinFromCurveLP is IPriceOracle {
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

    function latestAnswer() external view returns (uint256) {
        OracleCoinFromCurveLPStruct memory params = oracleParams;

        uint256 priceOtherStable = params.otherStableOracle.latestAnswer() * 10 ** (18 - params.otherStableDecimals);

        uint256 priceOracle = params.isReversed ? 1e36 / _priceOracle(params.lp, params.isParamsForPriceOracle) : _priceOracle(params.lp, params.isParamsForPriceOracle);

        return (priceOracle * priceOtherStable) / 1e18;
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
