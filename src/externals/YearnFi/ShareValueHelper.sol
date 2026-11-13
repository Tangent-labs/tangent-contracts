// SPDX-License-Identifier: AGLP-3.0
pragma solidity ^0.8.19;

import {IYearnVaultV2} from "./IYearnVaultV2.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Share Value Helper
 * @dev This works on all Yearn vaults 0.4.0+
 * @dev Achieves a higher precision conversion than pricePerShare; particularly for tokens with < 18 decimals.
 */
library ShareValueHelper {
    /**
     * @notice Helper function to convert underlying amount to vault shares with exact precision.
     * @param _vault The address of the vault token.
     * @param _amount The amount of underlying to convert to shares.
     * @param _useCeiling Whether to round up or not.
     * @return shares The shares of vault token.
     */
    function amountToShares(
        address _vault,
        uint256 _amount,
        bool _useCeiling
    ) internal view returns (uint256 shares) {
        uint256 totalSupply = IYearnVaultV2(_vault).totalSupply();
        if (totalSupply > 0) {
            if (_useCeiling) {
                shares = Math.ceilDiv(
                    _amount * totalSupply,
                    calculateFreeFunds(_vault)
                );
            } else {
                shares = (_amount * totalSupply) / calculateFreeFunds(_vault);
            }
        }
    }

    /**
     * @notice Helper function to convert shares to underlying amount with exact precision.
     * @param _vault The address of the vault token.
     * @param _shares The amount of shares to convert to underlying.
     * @param _useCeiling Whether to round up or not.
     * @return amount The amount of underlying token.
     */
    function sharesToAmount(
        address _vault,
        uint256 _shares,
        bool _useCeiling
    ) internal view returns (uint256 amount) {
        uint256 totalSupply = IYearnVaultV2(_vault).totalSupply();
        if (totalSupply == 0) return _shares;

        uint256 freeFunds = calculateFreeFunds(_vault);

        if (_useCeiling) {
            amount = Math.ceilDiv(_shares * freeFunds, totalSupply);
        } else {
            amount = ((_shares * freeFunds) / totalSupply);
        }
    }

    function calculateFreeFunds(
        address _vault
    ) internal view returns (uint256) {
        uint256 totalAssets = IYearnVaultV2(_vault).totalAssets();
        uint256 lockedFundsRatio = (block.timestamp -
            IYearnVaultV2(_vault).lastReport()) *
            IYearnVaultV2(_vault).lockedProfitDegradation();

        if (lockedFundsRatio < 10 ** 18) {
            uint256 lockedProfit = IYearnVaultV2(_vault).lockedProfit();
            lockedProfit -= ((lockedFundsRatio * lockedProfit) / 10 ** 18);
            return totalAssets - lockedProfit;
        } else {
            return totalAssets;
        }
    }
}
