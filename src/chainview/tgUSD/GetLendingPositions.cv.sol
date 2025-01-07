// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICollateral} from "../../interfaces/internals/tgUSD/ICollateral.sol";
import {IDebtIR} from "../../interfaces/internals/tgUSD/IDebtIR.sol";

contract GetLendingPositions {
    struct GetLendingPositionsIn {
        address account;
        address market;
    }

    struct GetLendingPositionsOut {
        uint256 healthRatio;
        uint256 positionDebt;
        uint256 positionValue;
        uint256 maxLTV;
    }

    error GetLendingPositionsError(GetLendingPositionsOut[] output);

    constructor(GetLendingPositionsIn[] memory usersMarkets) {
        GetLendingPositionsOut[] memory output = new GetLendingPositionsOut[](usersMarkets.length);
        for (uint256 index; index < usersMarkets.length; index++) {
            address market = usersMarkets[index].market;
            address account = usersMarkets[index].account;

            ICollateral marketCollateral = ICollateral(market);
            output[index] = GetLendingPositionsOut({
                healthRatio: marketCollateral.healthRatio(account),
                positionDebt: IDebtIR(market).positionDebt(account),
                positionValue: marketCollateral.positionValue(account),
                maxLTV: marketCollateral.maxLTV()
            });
        }
        revert GetLendingPositionsError(output);
    }
}
