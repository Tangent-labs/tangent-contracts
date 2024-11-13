import "../../contexts/ConvexCurveContext.sol";

import "../../handler/HProcessRewards.sol";
import "../../handler/HDepositConvexCrvLP.sol";
import "../../handler/HBorrow.sol";
contract ProcessRewardsAndClaimCvxMarket is ConvexCurveContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexCrvLP public hDeposit;
    HBorrow public hBorrow;
    uint256 minimumLoan;

    function setUp() public {
        deployBaseContracts();
        collatToken = AddrCurveStableLP.CRVUSD_USDC;
        market = deployConvexCurveLPMarket(collatToken);

        hRewards = new HProcessRewards(usr1, market);
        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        minimumLoan = market.minimumLoan();
    }

    function minimumCollatForDebt(uint256 userDebt) internal view returns (uint256) {
        return 2 + (userDebt * 1 ether * 100_000) / (market.collatOracle().latestAnswer() * 85_000);
    }

    function test_processRewards_claim(uint256 collatDeposited, uint256 borrowedAmount, uint256 repayAmount) external {
        borrowedAmount = bound(borrowedAmount, minimumLoan, market.maxMarketDebt());
        collatDeposited = bound(collatDeposited, minimumCollatForDebt(borrowedAmount), 2_000_000 ether);

        hDeposit.deposit(usr1, collatDeposited, true);

        vm.startPrank(usr1);
        hBorrow.borrow(usr2, borrowedAmount);

        skip(15 days);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        irMinter.mintIR(markets);
        vm.stopPrank();

        hRewards.processRewards(usr2);

        skip(7 days);
        vm.startPrank(usr1);
        rewardAccumulator.claimSimple(address(market));

        rewardAccumulator.claimCutFees(market.getRewardTokens());

        assertLt(market.rewardTokens(0).balanceOf(address(rewardAccumulator)), 10 ** 7);

        vm.stopPrank();
    }
}
