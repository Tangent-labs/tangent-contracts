// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

contract DebtIndexIncrease is ConvexCurveContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;
    function setUp() public {
        collatToken = AddrCurveStableLP.CRVUSD_USDC;
        market = deployConvexCurveLPMarket(collatToken);
    }

    function test_debtIndex_increases(uint24 daysToSkip1, uint32 daysToSkip2) external {
        uint256 lastIr = market.lastIR();
        uint256 debtIndex = market.debtIndex();

        assertEq(debtIndex, 1 ether, "Debt index should be 1");

        uint256 skipDuration = uint256(daysToSkip1) * 1 days;

        skip(skipDuration);

        uint256 indexIncrem1 = (lastIr * skipDuration) / 365 days;

        market.checkpointIR();

        debtIndex = market.debtIndex();

        assertEq(debtIndex, 1 ether + indexIncrem1, "Debt index should be equal to the incremented index");

        uint256 skipDuration2 = uint256(daysToSkip2) * 1 days;

        skip(skipDuration2);

        uint256 indexIncrem2 = (lastIr * skipDuration2) / 365 days;

        market.checkpointIR();

        assertEq(market.debtIndex(), debtIndex + indexIncrem2, "Debt index should be equal to the incremented index");
    }
}
