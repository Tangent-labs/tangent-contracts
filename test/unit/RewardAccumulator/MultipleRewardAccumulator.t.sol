// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../../handler/Features/HProcessRewards.sol";
import "../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

import "../../mocks/MarketCreator2Mock.sol";

contract MultipleRewardAccumulator is MarketDeploymentContext {
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
    RewardAccumulator rewardAccumulator2;

    uint256 collatDeposited = 100_000 ether;

    function setUp() public {
        // Deploy new market creator and new rewardAccumulator
        vm.startPrank(owner);
        rewardAccumulator2 = new RewardAccumulator(owner, controlTower, USGOracle);
        marketCreator2Mock = new MarketCreator2Mock(owner, controlTower, usg, irCalculator, rewardAccumulator2, zappingProxy, convexCrvLPMarketImplem);
        controlTower.setIsMarketCreator(address(marketCreator2Mock), true);

        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployConvexCurveLPMarket(collatToken);

        vm.startPrank(owner);

        ParamsInitConvexCurveLPMarket memory initP = cvxCurveLPMaps[address(collatToken)];
        market2 = ConvexCrvLPMarket(
            marketCreator2Mock.createConvexCrvMarket(getMarketInit(initP.marketInit, new IERC20[](0), collatToken), initP.pid, getBaseIRParamsLEC(), getBaseRCParams())
        );
        vm.stopPrank();

        hDeposit = new HDepositConvexCrvLP(usr1, market, usg, marketViewer);
        hDeposit2 = new HDepositConvexCrvLP(usr2, market2, usg, marketViewer);

        hDeposit.deposit(usr1, collatDeposited, true);
        hDeposit2.deposit(usr2, collatDeposited, true);

        hRewards = new HProcessRewards(usr1, market, rewardAccumulator, usg, marketViewer);
        hRewards2 = new HProcessRewards(usr2, market2, rewardAccumulator2, usg, marketViewer);

        vm.startPrank(usr1);

        skip(15 days);

        irCalculator.mintIR();
        vm.stopPrank();

        hRewards.processRewards(usr2);
        hRewards2.processRewards(usr2);

        skip(7 days);
    }

    function test_that_its_impossible_to_claim_rewards_on_the_wrong_rewardAccumulator() external {
        vm.startPrank(usr1);

        address[] memory markets = new address[](2);
        markets[0] = address(market);
        markets[1] = address(market2);
        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.NotAMarketRewards.selector));

        rewardAccumulator.claimMultiple(markets, 2);
    }
}
