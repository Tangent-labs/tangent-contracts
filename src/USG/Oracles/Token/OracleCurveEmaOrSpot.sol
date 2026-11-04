// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {ICurveTriCryptoSwap} from "../../../interfaces/externals/Curve/ICurveTriCryptoSwap.sol";
import {ICurveCryptoSwap} from "../../../interfaces/externals/Curve/ICurveCryptoSwap.sol";
import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {OracleBase} from "../OracleBase.sol";

enum CurvePoolType {
    CRYPTO, // 2 coins crypto (v2 / twocrypto-ng): price_oracle()
    TRICRYPTO, // price_oracle(k)
    STABLESWAP_NG // price_oracle(k), get_dy(int128, int128, uint256)
}

/// @title OracleCurveEmaOrSpot
/// @author Tangent Finance
/// @notice Prices a token from a Curve pool as max(EMA, spot).
/// @dev    ONLY meant for the FeeDispatcher sell floor, NEVER for collateral pricing.
///         The EMA lags a pump, which would let a dump fill below spot: taking the max closes that.
///         Spot is get_dy of 1 unit of the priced token: the current executable price (fee included), unlike last_prices which is the last trade's.
///         Spot is manipulable in the same tx, but through the max it can only raise the floor (dump reverts), never lower it.
///         The EMA can still be dragged over several blocks: ONLY use liquid pools.
///         `priceIndex` follows Curve: index k prices coin k+1 in coin 0 (coin 2 => k = 1). Always 0 on 2 coins crypto pools.
contract OracleCurveEmaOrSpot is OracleBase {
    address public immutable lp;
    IPriceOracle public immutable otherTokenOracle;
    CurvePoolType public immutable poolType;
    bool public immutable isReversed;
    uint256 public immutable priceIndex;
    // Spot = get_dy(indexIn, indexOut, unitIn) * 1e18 / unitOut: 1 priced token sold for the other token
    uint256 public immutable indexIn;
    uint256 public immutable indexOut;
    uint256 public immutable unitIn;
    uint256 public immutable unitOut;

    error UnsupportedPool();

    constructor(address _lp, IPriceOracle _otherTokenOracle, uint256 _priceIndex, bool _isReversed, string memory _oracleName) OracleBase(_oracleName) {
        lp = _lp;
        otherTokenOracle = _otherTokenOracle;
        poolType = _detectPoolType(_lp);
        isReversed = _isReversed;
        priceIndex = _priceIndex;
        (uint256 _i, uint256 _j) = _isReversed ? (uint256(0), _priceIndex + 1) : (_priceIndex + 1, uint256(0));
        indexIn = _i;
        indexOut = _j;
        unitIn = 10 ** IERC20Metadata(ICurveCryptoSwap(_lp).coins(_i)).decimals();
        unitOut = 10 ** IERC20Metadata(ICurveCryptoSwap(_lp).coins(_j)).decimals();
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
        uint256 dy;
        if (poolType == CurvePoolType.CRYPTO) {
            ema = ICurveCryptoSwap(lp).price_oracle();
            dy = ICurveCryptoSwap(lp).get_dy(indexIn, indexOut, unitIn);
        } else if (poolType == CurvePoolType.TRICRYPTO) {
            ema = ICurveTriCryptoSwap(lp).price_oracle(priceIndex);
            dy = ICurveTriCryptoSwap(lp).get_dy(indexIn, indexOut, unitIn);
        } else {
            ema = ICurveStableSwapNG(lp).price_oracle(priceIndex);
            dy = ICurveStableSwapNG(lp).get_dy(int128(int256(indexIn)), int128(int256(indexOut)), unitIn);
        }

        // Reverse before taking the max, so the max is always on the priced token. get_dy is already in the priced token direction
        if (isReversed) ema = 1e36 / ema;
        uint256 spot = (dy * 1e18) / unitOut;

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
