// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../contexts/MarketDeploymentContext.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";
import {MarketAccountLiquidationBotInfo} from "../../../src/chainview/tgUSD/bot/MarketAccountLiquidationBotInfo.cv.sol";
import {GetAccountLiquidation} from "../../../src/chainview/tgUSD/GetAccountLiquidation.sol";
contract MarketAccountLiquidationBotInfoChainview is MarketDeploymentContext {
    ConvexCrvLPMarket public market1;
    ConvexCrvLPMarket public market2;

    function setUp() public {
        market1 = deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD);
        market2 = deployConvexCurveLPMarket(AddrCurveStableLP.WETH_frxETH);
    }

    // LIST
    function test_MarketAccountLiquidationBot_returns() public {
        address[] memory markets = new address[](2);
        markets[0] = address(market1);
        markets[1] = address(market2);
        GetAccountLiquidation.LendingPositionsIn[] memory usersMarkets = new GetAccountLiquidation.LendingPositionsIn[](2);
        usersMarkets[0] = GetAccountLiquidation.LendingPositionsIn({account: usr1, market: address(market1)});
        usersMarkets[1] = GetAccountLiquidation.LendingPositionsIn({account: usr1, market: address(market2)});

        try new MarketAccountLiquidationBotInfo(markets, usersMarkets) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}
