// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
contract ViewsControlTower is MarketDeploymentContext {
    function test_init_controlTower() external view {
        assertEq(controlTower.owner(), owner);
        assertEq(controlTower.feeTreasury(), feeTreasury);
    }

    function test_getFeeTreasuryAndIsIRCalculator() external view {
        (address feeT, bool isIRCalc) = controlTower.getFeeTreasuryAndIsIRCalculator(address(irCalculator));

        assertEq(feeTreasury, feeT);
        assertTrue(isIRCalc);

        (feeT, isIRCalc) = controlTower.getFeeTreasuryAndIsIRCalculator(usr2);

        assertEq(feeTreasury, feeT);
        assertFalse(isIRCalc);
    }

    function test_areContractsMarkets() external {
        address market1 = address(deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD, true));
        address market2 = address(deployConvexFxnLPMarket(AddrCurveStableLP.USDC_fxUSD));
        address market3 = address(deployMarketNoSociabilisation(AddrPTPendle.sUSDe_31_07_25));

        assertTrue(controlTower.areContractsMarkets(Array.memoryAddress([market1, market2, market3])));
        assertFalse(controlTower.areContractsMarkets(Array.memoryAddress([market1, address(0), market3])));
        assertFalse(controlTower.areContractsMarkets(Array.memoryAddress([market1, market3, address(0)])));
        assertFalse(controlTower.areContractsMarkets(Array.memoryAddress([address(0), market3, market1])));
    }
}
