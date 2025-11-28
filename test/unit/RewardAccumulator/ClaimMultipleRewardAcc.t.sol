// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../../handler/Features/HProcessRewards.sol";
import "../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract ClaimMultipleRewardAcc is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    ConvexFxnLPMarket public market2;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HProcessRewards public hRewards2;
    HDepositConvexCrvLP public hDeposit;
    HDepositConvexFxnLP public hDeposit2;

    HBorrow public hBorrow;
    uint256 minimumLoan;

    uint256 collatDeposited = 100_000 ether;

    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployConvexCurveLPMarket(collatToken);
        market2 = deployConvexFxnLPMarket(AddrCurveStableLP.USDC_fxUSD);
        hRewards = new HProcessRewards(usr1, market, rewardAccumulator, usg, marketViewer);
        hRewards2 = new HProcessRewards(usr1, market2, rewardAccumulator, usg, marketViewer);
        hDeposit = new HDepositConvexCrvLP(usr1, market, usg, marketViewer);
        hDeposit2 = new HDepositConvexFxnLP(usr1, market2, usg, marketViewer);
        hBorrow = new HBorrow(usr1, market, usg, marketViewer);
        minimumLoan = market.minimumLoan();

        hDeposit.deposit(usr1, collatDeposited, false);
        hDeposit2.deposit(usr1, collatDeposited, false);

        vm.startPrank(usr1);

        skip(15 days);

        irCalculator.mintIR();
        vm.stopPrank();

        hRewards.processRewards(usr2);
        hRewards2.processRewards(usr2);

        skip(7 days);
    }

    function test_claimMultiple_with_1_token_in_common() external {
        vm.startPrank(usr1);

        rewardAccumulator.claimMultiple(Array.memoryAddress([address(market), address(market2)]), 3);
        rewardAccumulator.claimCutFees(rewardAccumulator.getRewardTokens(address(market)));

        assertLt(rewardAccumulator.rewardTokens(address(market), 0).balanceOf(address(rewardAccumulator)), 10 ** 7);

        vm.stopPrank();
    }

    function test_claimMultiple_with_wrong_reward_len() external {
        vm.startPrank(usr1);
        address[] memory marketArrays = Array.memoryAddress([address(market), address(market2)]);

        vm.expectRevert();
        rewardAccumulator.claimMultiple(marketArrays, 2);

        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.IncorrectRewardLength.selector, 4, 3));
        rewardAccumulator.claimMultiple(marketArrays, 4);
    }

    function test_claimMultiple_fails_because_one_market_in_params_is_not_a_market() external {
        vm.startPrank(usr1);
        address[] memory marketArrays = Array.memoryAddress([address(market), usr1]);

        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.NotAMarketRewards.selector));
        rewardAccumulator.claimMultiple(marketArrays, 2);
    }

    function test_claimMultiple_fails_because_one_market_has_no_rewards() external {
        vm.startPrank(usr1);

        rewardAccumulator.claimSimple(address(market));

        address[] memory marketArrays = Array.memoryAddress([address(market), address(market2)]);

        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.NoRewardsToClaimFromContract.selector, address(market)));
        rewardAccumulator.claimMultiple(marketArrays, 2);
    }
}
