// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ILiquidatorProxy} from "../../interfaces/internals/tgUSD/ILiquidatorProxy.sol";

contract LiquidatorProxy is ILiquidatorProxy {
    error LiquidatorCallError();

    function callLiquidate(address liquidator, bytes calldata liquidationCall) external {
        (bool isrouterCallSuccess, ) = liquidator.call(liquidationCall);
        require(isrouterCallSuccess, LiquidatorCallError());
    }
}
