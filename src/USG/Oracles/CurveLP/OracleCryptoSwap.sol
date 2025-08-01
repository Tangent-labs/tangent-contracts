// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {ICurveTriCryptoSwap} from "../../../interfaces/externals/Curve/ICurveTriCryptoSwap.sol";
import {OracleBase} from "../OracleBase.sol";

/// @title OracleCryptoSwap
/// @notice This contract provides price oracle functionality for a dual pool cryptoswap of Curve Finance.
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

    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        OracleCryptoSwapStruct memory _params = params;

        return (ICurveTriCryptoSwap(_params.lp).lp_price() * _coinPrice(_params.coin0Oracle, _params.coin0OracleDecimals, isNoFailMode)) / 1e18;
    }
}
