// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICollateral} from "../../interfaces/internals/USG/ICollateral.sol";
import {IDebtIR} from "../../interfaces/internals/USG/IDebtIR.sol";
import {IMarketViewer} from "../../interfaces/internals/USG/IMarketViewer.sol";

contract GetAccountLiquidation {
    struct LendingPositionsIn {
        address account;
        address market;
    }

    struct AccountLiquidationInfo {
        address market;
        uint256 healthRatio;
        uint256 userDebt;
        uint256 positionValue;
        uint256 collateralBalance;
    }

    function getAccountLiquidationInfo(LendingPositionsIn[] memory usersMarkets, IMarketViewer _marketViewer) public view returns (AccountLiquidationInfo[] memory) {
        AccountLiquidationInfo[] memory output = new AccountLiquidationInfo[](usersMarkets.length);
        for (uint256 index; index < usersMarkets.length; index++) {
            address market = usersMarkets[index].market;
            address account = usersMarkets[index].account;
            ICollateral marketCollateral = ICollateral(market);
            output[index] = AccountLiquidationInfo({
                market: market,
                healthRatio: _marketViewer.healthRatio(market, account),
                userDebt: _marketViewer.userDebt(IDebtIR(market), account),
                positionValue: _marketViewer.positionValue(ICollateral(market), account),
                collateralBalance: marketCollateral.collateralBalances(account)
            });
        }
        return output;
    }
}
