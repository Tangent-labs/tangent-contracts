// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";

import {OracleBase} from "../OracleBase.sol";

contract OracleTriPoolStable is OracleBase {
    struct OracleTriPoolStruct {
        IPriceOracle coin0Oracle;
        uint96 coin0OracleDecimals;
        IPriceOracle coin1Oracle;
        uint96 coin1OracleDecimals;
        IPriceOracle coin2Oracle;
        uint96 coin2OracleDecimals;
        ICurveStableSwapNG lp;
    }
    OracleTriPoolStruct public params;

    constructor(address _lp, IPriceOracle _coin0Oracle, IPriceOracle _coin1Oracle, IPriceOracle _coin2Oracle) {
        params = OracleTriPoolStruct({
            coin0Oracle: _coin0Oracle,
            coin1Oracle: _coin1Oracle,
            coin2Oracle: _coin2Oracle,
            lp: ICurveStableSwapNG(_lp),
            coin0OracleDecimals: uint96(_coin0Oracle.decimals()),
            coin1OracleDecimals: uint96(_coin1Oracle.decimals()),
            coin2OracleDecimals: uint96(_coin2Oracle.decimals())
        });
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return b;
        }
        return a;
    }

    function latestAnswer() external view override returns (uint256) {
        OracleTriPoolStruct memory _params = params;
        uint256 answer0 = _coinPrice(_params.coin0Oracle, _params.coin0OracleDecimals);
        uint256 answer1 = _coinPrice(_params.coin1Oracle, _params.coin1OracleDecimals);
        uint256 answer2 = _coinPrice(_params.coin2Oracle, _params.coin2OracleDecimals);

        return (_params.lp.get_virtual_price() * min(answer0, min(answer1, answer2))) / 10 ** 18;
    }
}
