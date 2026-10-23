// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {ICurveTriCryptoSwap} from "../../../interfaces/externals/Curve/ICurveTriCryptoSwap.sol";
import {ICurveCryptoSwap} from "../../../interfaces/externals/Curve/ICurveCryptoSwap.sol";
import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {OracleBase} from "../OracleBase.sol";

enum CurvePoolType {
    CRYPTO, // 2 coins crypto (v2 / twocrypto-ng): price_oracle(), last_prices()
    TRICRYPTO, // price_oracle(0), last_prices(0)
    STABLESWAP_NG // price_oracle(0), get_p(0)
}

/// @title OracleCurveEmaOrSpot
/// @author Tangent Finance
/// @notice Prices a token from a Curve pool as max(EMA, spot).
/// @dev    ONLY meant for the FeeDispatcher sell floor, NEVER for collateral pricing.
///         The EMA lags a pump, which would let a dump fill below spot: taking the max closes that.
///         Spot is manipulable in the same tx, but through the max it can only raise the floor (dump reverts), never lower it.
contract OracleCurveEmaOrSpot is OracleBase {
    address public immutable lp;
    IPriceOracle public immutable otherTokenOracle;
    CurvePoolType public immutable poolType;
    bool public immutable isReversed;

    error UnsupportedPool();

    constructor(address _lp, IPriceOracle _otherTokenOracle, bool _isReversed, string memory _oracleName) OracleBase(_oracleName) {
        lp = _lp;
        otherTokenOracle = _otherTokenOracle;
        poolType = _detectPoolType(_lp);
        isReversed = _isReversed;
    }

    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        return _computePrice(otherTokenOracle.latestAnswer(isNoFailMode));
    }

    function latestAnswerUpdate(bool isNoFailMode) external override returns (uint256) {
        return _computePrice(otherTokenOracle.latestAnswerUpdate(isNoFailMode));
    }

    function _computePrice(uint256 priceOtherToken) internal view returns (uint256) {
        uint256 ema;
        uint256 spot;
        if (poolType == CurvePoolType.CRYPTO) {
            ema = ICurveCryptoSwap(lp).price_oracle();
            spot = ICurveCryptoSwap(lp).last_prices();
        } else if (poolType == CurvePoolType.TRICRYPTO) {
            ema = ICurveTriCryptoSwap(lp).price_oracle(0);
            spot = ICurveTriCryptoSwap(lp).last_prices(0);
        } else {
            ema = ICurveStableSwapNG(lp).price_oracle(0);
            spot = ICurveStableSwapNG(lp).get_p(0);
        }

        // Reverse before taking the max, so the max is always on the priced token
        if (isReversed) {
            ema = 1e36 / ema;
            spot = 1e36 / spot;
        }

        return ((ema > spot ? ema : spot) * priceOtherToken) / 1e18;
    }

    /// @dev Low level calls: crypto pools have a payable `__default__`, unknown selectors succeed with empty returndata.
    function _detectPoolType(address lp) internal view returns (CurvePoolType) {
        if (_returnsWord(lp, abi.encodeWithSignature("price_oracle()"))) return CurvePoolType.CRYPTO;
        if (_returnsWord(lp, abi.encodeWithSignature("last_prices(uint256)", 0))) return CurvePoolType.TRICRYPTO;
        if (_returnsWord(lp, abi.encodeWithSignature("get_p(uint256)", 0))) return CurvePoolType.STABLESWAP_NG;
        revert UnsupportedPool();
    }

    function _returnsWord(address lp, bytes memory data) internal view returns (bool) {
        (bool success, bytes memory ret) = lp.staticcall(data);
        return success && ret.length >= 32;
    }
}
