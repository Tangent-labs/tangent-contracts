// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
contract AccessControlMarkets is MarketDeploymentContext {
    ConvexCrvLPMarket market;

    function setUp() public {
        market = deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD, true);
        vm.startPrank(owner);
    }
    function test_setCollatOracle_success() external {
        market.setCollatOracle(IPriceOracle(usr2));

        assertEq(address(market.collatOracle()), usr2);
    }
}
