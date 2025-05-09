// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IPriceOracle} from "../../../interfaces/internals/tgUSD/IPriceOracle.sol";
import {ICurveTriCryptoSwap} from "../../../interfaces/externals/Curve/ICurveTriCryptoSwap.sol";
import {OracleBase} from "../OracleBase.sol";

import "forge-std/console.sol";

contract OracleCryptoSwap is OracleBase {
    struct OracleCryptoSwapStruct {
        address lp;
        IPriceOracle coin0Oracle;
        uint192 coin0OracleDecimals;
    }
    OracleCryptoSwapStruct public params;

    constructor(address _lp, IPriceOracle coin0Oracle) {
        params = OracleCryptoSwapStruct({lp: _lp, coin0Oracle: coin0Oracle, coin0OracleDecimals: uint192(coin0Oracle.decimals())});
    }

    function latestAnswer() external view override returns (uint256) {
        OracleCryptoSwapStruct memory _params = params;

        return (ICurveTriCryptoSwap(_params.lp).lp_price() * _coinPrice(_params.coin0Oracle, _params.coin0OracleDecimals)) / 1e18;
    }
}
