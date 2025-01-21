// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IMarketExternalActions} from "../../interfaces/internals/tgUSD/IMarketExternalActions.sol";

contract CurveLPLiquidator {
    struct LiquidateCall {
        address market;
        address account;
        uint256 tgUSDToRepay;
        address liquidator;
    }

    struct UnwrapLP {
        address account;
        uint256 tgUSDToRepay;
        address liquidator;
    }

    struct BuyTgUSD {
        address account;
        uint256 tgUSDToRepay;
        address liquidator;
    }

    function liquidateLP(LiquidateCall calldata _liquidateCall, UnwrapLP calldata _unwrapLP, BuyTgUSD calldata _buyTgUSD, bytes memory liquidation) external {
        IMarketExternalActions(_liquidateCall.market).liquidate(_liquidateCall.account, _liquidateCall.tgUSDToRepay, address(this), liquidation);
    }
}
