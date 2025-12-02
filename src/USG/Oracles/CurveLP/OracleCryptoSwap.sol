// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {ICurveTriCryptoSwap} from "../../../interfaces/externals/Curve/ICurveTriCryptoSwap.sol";
import {OracleBase} from "../OracleBase.sol";

/// @title OracleCryptoSwap
/// @author Tangent Finance
/// @notice This contract provides price oracle functionality for a cryptoswap pool of Curve Finance.
contract OracleCryptoSwap is OracleBase {
    struct OracleCryptoSwapStruct {
        address lp;
        IPriceOracle coin0Oracle;
        uint96 coin0OracleDecimals;
    }
    OracleCryptoSwapStruct public params;

    constructor(address _lp, IPriceOracle coin0Oracle, string memory _oracleName) OracleBase(_oracleName) {
        params = OracleCryptoSwapStruct({lp: _lp, coin0Oracle: coin0Oracle, coin0OracleDecimals: uint96(coin0Oracle.decimals())});
    }

    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        OracleCryptoSwapStruct memory _params = params;
        return _computePrice(_params.lp, _params.coin0Oracle.latestAnswer(isNoFailMode));
    }

    function latestAnswerUpdate(bool isNoFailMode) external override returns (uint256) {
        OracleCryptoSwapStruct memory _params = params;
        return _computePrice(_params.lp, _params.coin0Oracle.latestAnswerUpdate(isNoFailMode));
    }

    function _computePrice(address lp, uint256 coin0Price) internal view returns (uint256) {
        return (ICurveTriCryptoSwap(lp).lp_price() * coin0Price) / 1e18;
    }
}
