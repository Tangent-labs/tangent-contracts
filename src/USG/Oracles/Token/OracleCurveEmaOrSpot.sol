// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {ICurveTriCryptoSwap} from "../../../interfaces/externals/Curve/ICurveTriCryptoSwap.sol";
import {ICurveCryptoSwap} from "../../../interfaces/externals/Curve/ICurveCryptoSwap.sol";
import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {OracleBase} from "../OracleBase.sol";

enum CurvePoolType {
    CRYPTO, // 2 coins crypto (v2 / twocrypto-ng): price_oracle(), last_prices()
    TRICRYPTO, // price_oracle(k), last_prices(k)
    STABLESWAP_NG // price_oracle(k), get_p(k)
}

/// @title OracleCurveEmaOrSpot
/// @author Tangent Finance
/// @notice Prices a token from a Curve pool as max(EMA, spot).
/// @dev    ONLY meant for the FeeDispatcher sell floor, NEVER for collateral pricing.
///         The EMA lags a pump, which would let a dump fill below spot: taking the max closes that.
///         Spot is manipulable in the same tx, but through the max it can only raise the floor (dump reverts), never lower it.
///         The EMA can still be dragged over several blocks: ONLY use liquid pools.
///         `priceIndex` follows Curve: index k prices coin k+1 in coin 0 (coin 2 => k = 1). Always 0 on 2 coins crypto pools.
contract OracleCurveEmaOrSpot is OracleBase {
    address public immutable lp;
    IPriceOracle public immutable otherTokenOracle;
    CurvePoolType public immutable poolType;
    bool public immutable isReversed;
    uint256 public immutable priceIndex;

    error UnsupportedPool();

    constructor(address _lp, IPriceOracle _otherTokenOracle, uint256 _priceIndex, bool _isReversed, string memory _oracleName) OracleBase(_oracleName) {
        lp = _lp;
        otherTokenOracle = _otherTokenOracle;
        poolType = _detectPoolType(_lp);
        isReversed = _isReversed;
        priceIndex = _priceIndex;
        // Fails the deployment on a misdetected pool (old stableswap exposing price_oracle()) or a wrong priceIndex
        _computePrice(1e18);
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
            ema = ICurveTriCryptoSwap(lp).price_oracle(priceIndex);
            spot = ICurveTriCryptoSwap(lp).last_prices(priceIndex);
        } else {
            ema = ICurveStableSwapNG(lp).price_oracle(priceIndex);
            spot = ICurveStableSwapNG(lp).get_p(priceIndex);
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
