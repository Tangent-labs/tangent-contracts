// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {OracleBase} from "../OracleBase.sol";

/// @title OracleERC4626FromCurveLP
/// @author Tangent Finance
/// @notice Prices an ERC4626 at its market rate (premium / discount to NAV included) from a 2 coins Curve StableSwap NG pool.
/// @dev    Works only for NG pools
///         The real price of 1 whole coin1 in coin0 is `price_oracle * rate1 / rate0 * 10 ** (dec1 - dec0)`.
///         Works whatever the asset type of both coins (standard, oracle, ERC4626): their rates are divided out,
///         so `otherOracle` must price the other coin itself (ex sUSDS, not USDS).
contract OracleERC4626FromCurveLP is OracleBase {
    ICurveStableSwapNG public immutable lp;
    uint256 public immutable vaultIndex;
    // vault decimals - other decimals + 18, scales the NG rate to 18 decimals per whole token
    uint256 public immutable decimalsScaleExp;
    IPriceOracle public immutable otherOracle;

    error InvalidOracleDecimals();
    error OnlyTwoCoinsPool();
    error InvalidVaultIndex();

    constructor(ICurveStableSwapNG _lp, uint8 _vaultIndex, IPriceOracle _otherOracle, string memory _oracleName) OracleBase(_oracleName) {
        require(_otherOracle.decimals() == 18, InvalidOracleDecimals());
        require(_vaultIndex < 2, InvalidVaultIndex());

        // Reverts on non NG pools
        _lp.price_oracle(0);
        require(_lp.N_COINS() == 2, OnlyTwoCoinsPool());

        uint256 vaultDecimals = IERC20Metadata(_lp.coins(_vaultIndex)).decimals();
        uint256 otherDecimals = IERC20Metadata(_lp.coins(1 - _vaultIndex)).decimals();

        lp = _lp;
        vaultIndex = _vaultIndex;
        decimalsScaleExp = vaultDecimals + 18 - otherDecimals;
        otherOracle = _otherOracle;
    }

    /**
     * @notice Returns the market price of the ERC4626 in $.
     * @dev    Uses the EMA `price_oracle`, protected from flash manipulations.
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        return _computePrice(otherOracle.latestAnswer(isNoFailMode));
    }

    function latestAnswerUpdate(bool isNoFailMode) external override returns (uint256) {
        return _computePrice(otherOracle.latestAnswerUpdate(isNoFailMode));
    }

    function _computePrice(uint256 otherPrice) internal view returns (uint256) {
        // Rate-adjusted price of the vault in the other coin
        uint256 p = lp.price_oracle(0);
        if (vaultIndex == 0) p = 1e36 / p;

        // Real price of 1 whole vault token in the other coin, 18 decimals
        uint256[] memory rates = lp.stored_rates();
        p = (p * rates[vaultIndex] * 10 ** decimalsScaleExp) / rates[1 - vaultIndex] / 1e18;
        return (p * otherPrice) / 1e18;
    }
}
