// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../../contexts/MarketDeploymentContext.sol";
import "../../../src/chainview/USG/bot/PointPrices.cv.sol";

import {console} from "forge-std/console.sol";

contract PointPricesChainviewTest is MarketDeploymentContext {
    address public constant sCRVUSD = 0x0655977FEb2f289A4aB78af67BAB0d17aAb84367;

    PointPrices public pointPrices;

    function test_point_prices_returns() public {
        address[] memory erc4626s = new address[](1);
        erc4626s[0] = sCRVUSD;

        address[] memory pegKeepers = new address[](2);
        pegKeepers[0] = address(pegKeeperUSG_USDC);
        pegKeepers[1] = address(pegKeeperUSG_wcrvUSD);

        PointPrices.AddressesInput memory addresses = PointPrices.AddressesInput({usg: address(usg), usgOracle: address(USGOracle), sUsg: address(sUSG), pegKeepers: pegKeepers});

        MarketExternalActions m1 = deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD);
        MarketExternalActions m2 = deployConvexFxnLPMarket(AddrCurveStableLP.USDC_fxUSD);

        address[] memory markets = new address[](2);
        markets[0] = address(m1);
        markets[1] = address(m2);

        try new PointPrices(erc4626s, addresses, markets) {} catch (bytes memory reason) {
            console.logBytes(reason);
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}
