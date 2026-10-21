// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {OracleBase} from "../OracleBase.sol";

// 2 slots: [lp | vaultIndex | decimalsScaleExp] [otherOracle]
struct OracleERC4626FromCurveLPStruct {
    ICurveStableSwapNG lp;
    uint8 vaultIndex;
    // vault decimals - other decimals + 18, scales the NG rate to 18 decimals per whole token
    uint8 decimalsScaleExp;
    IPriceOracle otherOracle;
}

/// @title OracleERC4626FromCurveLP
/// @author Tangent Finance
/// @notice Prices an ERC4626 at its market rate (premium / discount to NAV included) from a 2 coins Curve StableSwap NG pool.
/// @dev    Works only for NG pools
///         The real price of 1 whole coin1 in coin0 is `price_oracle * rate1 / rate0 * 10 ** (dec1 - dec0)`.
///         Works whatever the asset type of both coins (standard, oracle, ERC4626): their rates are divided out,
///         so `otherOracle` must price the other coin itself (ex sUSDS, not USDS).
contract OracleERC4626FromCurveLP is OracleBase {
    OracleERC4626FromCurveLPStruct public params;

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

        params = OracleERC4626FromCurveLPStruct({lp: _lp, vaultIndex: _vaultIndex, decimalsScaleExp: uint8(vaultDecimals + 18 - otherDecimals), otherOracle: _otherOracle});
    }

    /**
     * @notice Returns the market price of the ERC4626 in $.
     * @dev    Uses the EMA `price_oracle`, protected from flash manipulations.
     */
    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        OracleERC4626FromCurveLPStruct memory _params = params;
        return _computePrice(_params, _params.otherOracle.latestAnswer(isNoFailMode));
    }

    function latestAnswerUpdate(bool isNoFailMode) external override returns (uint256) {
        OracleERC4626FromCurveLPStruct memory _params = params;
        return _computePrice(_params, _params.otherOracle.latestAnswerUpdate(isNoFailMode));
    }

    function _computePrice(OracleERC4626FromCurveLPStruct memory _params, uint256 otherPrice) internal view returns (uint256) {
        // Rate-adjusted price of the vault in the other coin
        uint256 p = _params.lp.price_oracle(0);
        if (_params.vaultIndex == 0) p = 1e36 / p;

        // Real price of 1 whole vault token in the other coin, 18 decimals
        uint256[] memory rates = _params.lp.stored_rates();
        p = (p * rates[_params.vaultIndex] * 10 ** _params.decimalsScaleExp) / rates[1 - _params.vaultIndex] / 1e18;
        return (p * otherPrice) / 1e18;
    }
}
