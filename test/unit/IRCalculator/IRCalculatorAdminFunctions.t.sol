// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
contract IRCalculatorAdminFunctions is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    function setUp() public {
        market = deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD, true);
    }

    function test_setTgUSDOracle_success() external {
        vm.startPrank(owner);
        irCalculator.setTgUSDOracle(IAggregatorStablePriceV3(usr2));
        assertEq(usr2, address(irCalculator.tgUSDOracle()));
    }

    function test_updateIRParams_success() external {
        vm.startPrank(owner);

        IRCheckpoint memory irCheck = irCalculator.getIRCheckpoint(address(market));
        assertEq(irCheck.ir, 0);

        irCalculator.updateIRParams(address(market), IRParams(false, 5_000, 100_000, 0, 0, 0, 0, 0, 0));

        irCheck = irCalculator.getIRCheckpoint(address(market));

        assertEq(irCheck.ir, 5e16);
    }
}
