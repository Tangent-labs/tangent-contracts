// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICollateral} from "../../interfaces/internals/tgUSD/ICollateral.sol";
import {IDebtIR} from "../../interfaces/internals/tgUSD/IDebtIR.sol";

contract GetAccountLiquidation {
    struct LendingPositionsIn {
        address account;
        address market;
    }

    struct AccountLiquidationInfo {
        uint256 healthRatio;
        uint256 positionDebt;
        uint256 positionValue;
    }

    function getAccountLiquidationInfo(LendingPositionsIn[] memory usersMarkets) public view returns (AccountLiquidationInfo[] memory) {
        AccountLiquidationInfo[] memory output = new AccountLiquidationInfo[](usersMarkets.length);
        for (uint256 index; index < usersMarkets.length; index++) {
            address market = usersMarkets[index].market;
            address account = usersMarkets[index].account;

            ICollateral marketCollateral = ICollateral(market);
            output[index] = AccountLiquidationInfo({
                healthRatio: marketCollateral.healthRatio(account),
                positionDebt: IDebtIR(market).positionDebt(account),
                positionValue: marketCollateral.positionValue(account)
            });
        }
        return output;
    }
}
