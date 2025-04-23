// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ILiquidatorProxy} from "../../interfaces/internals/tgUSD/ILiquidatorProxy.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {console} from "hardhat/console.sol";
contract LiquidatorProxy is ILiquidatorProxy {
    using SafeERC20 for IERC20;

    uint256 constant MAX_UINT = type(uint256).max;
    IERC20 public tgUSD;

    constructor(IERC20 _tgUSD) {
        tgUSD = _tgUSD;
    }

    error LiquidatorCallError();
    error MinAmountOutNotReached();

    function callLiquidate(address liquidator, address receiver, IERC20 assetToLiquidate, uint256 minTgUSDReceived, bytes calldata routerCall) external payable {
        if (assetToLiquidate.allowance(address(this), liquidator) != MAX_UINT) {
            assetToLiquidate.approve(liquidator, MAX_UINT);
        }
        IERC20 _tgUSD = tgUSD;
        uint256 bal = _tgUSD.balanceOf(receiver);
        // Call router router and perform the swaps with raw data following recommendations.
        (bool isRouterCallSuccess, ) = liquidator.call{value: msg.value}(routerCall);
        // Verify the call to router was successfull console.log("bcallLiquidate");
        console.log("before callLiquidate");
        require(isRouterCallSuccess, LiquidatorCallError());
        console.log("after callLiquidate");

        bal = _tgUSD.balanceOf(receiver) - bal;

        require(minTgUSDReceived <= bal, MinAmountOutNotReached());
    }
}
