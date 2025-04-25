// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
import "../../../utils/IRCalculationFFI.sol";

contract DebtIndexIncrease is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;
    IRCalculationFFI irFFI = new IRCalculationFFI();

    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployConvexCurveLPMarket(collatToken);
    }

    function test_debtIndex_increases(uint40 secondsToSkip1, uint40 secondsToSkip2) external {
        secondsToSkip1 = uint40(bound(uint256(secondsToSkip1), 0, 365 days * 100));
        secondsToSkip2 = uint40(bound(uint256(secondsToSkip2), 0, 365 days * 100));
        (uint216 ir, uint40 timestamp) = irCalculator.irCheckpoints(address(market));

        uint256 debtIndex = irCalculator.debtIndexes(address(market));

        assertEq(debtIndex, RAY, "Debt index should be 1");

        skip(uint256(secondsToSkip1));

        uint256 newExpectedIndex = irFFI.getIndexFFI(debtIndex, ir, timestamp);

        irCalculator.checkpointIR(address(market));

        debtIndex = irCalculator.debtIndexes(address(market));

        assertApproxEqRel(newExpectedIndex, debtIndex, 1e3); //0.0000000000001% delta

        (ir, timestamp) = irCalculator.irCheckpoints(address(market));

        skip(uint256(secondsToSkip2));

        newExpectedIndex = irFFI.getIndexFFI(debtIndex, ir, timestamp);

        irCalculator.checkpointIR(address(market));

        debtIndex = irCalculator.debtIndexes(address(market));

        assertApproxEqRel(newExpectedIndex, debtIndex, 1e3, "Debt index should be equal to the incremented index");
    }
}
