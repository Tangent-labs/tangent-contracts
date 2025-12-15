// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../../handler/Features/HProcessRewards.sol";
import "../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

import "../../mocks/MarketCreator2Mock.sol";

contract MultipleIRCalculator is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    ConvexCrvLPMarket public market2;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HProcessRewards public hRewards2;
    HDepositConvexCrvLP public hDeposit;
    HDepositConvexCrvLP public hDeposit2;

    HBorrow public hBorrow;
    IRParams public irParams;

    MarketCreator2Mock marketCreator2Mock;
    IRCalculator irCalculator2;

    uint256 collatDeposited = 100_000 ether;

    function setUp() public {
        irParams = IRParams({isHEC: false, rMin: 4_000, rMax: 400_000, pMin: 980_000, pMax: 1_000_000, pInf: 990_000, a1: 2_000, a2: 2_000, k: 250});

        // Deploy new market creator and new rewardAccumulator
        vm.startPrank(owner);
        irCalculator2 = new IRCalculator(owner, controlTower, USGOracle, usg);
        marketCreator2Mock = new MarketCreator2Mock(owner, controlTower, usg, irCalculator2, rewardAccumulator, zappingProxy, convexCrvLPMarketImplem);
        controlTower.setIsMarketCreator(address(marketCreator2Mock), true);

        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployConvexCurveLPMarket(collatToken);

        vm.startPrank(owner);

        ParamsInitConvexCurveLPMarket memory initP = cvxCurveLPMaps[address(collatToken)];
        market2 = ConvexCrvLPMarket(
            marketCreator2Mock.createConvexCrvMarket(getMarketInit(initP.marketInit, new IERC20[](0), collatToken), initP.pid, irParams, getBaseRCParams())
        );
        vm.stopPrank();

        vm.startPrank(usr1);
        deal(address(collatToken), usr1, collatDeposited);
        collatToken.approve(address(market), MAX_UINT);
        market.depositAndBorrow(collatDeposited, 10_000 ether, false);
        vm.stopPrank();

        vm.startPrank(usr2);
        deal(address(collatToken), usr2, collatDeposited);
        collatToken.approve(address(market2), MAX_UINT);
        market2.depositAndBorrow(collatDeposited, 10_000 ether, false);
        vm.stopPrank();

        skip(365 days);
    }

    function test_that_we_cannot_checkpoint_market_not_linked_to_the_right_IRCalculator() external {
        vm.startPrank(usr1);

        address[] memory markets = new address[](2);
        markets[0] = address(market);
        markets[1] = address(market2);
        vm.expectRevert(abi.encodeWithSelector(IRCalculator.NotAMarket.selector));

        irCalculator.checkpointIR(address(market2));

        irCalculator2.checkpointIR(address(market2));
    }
}
