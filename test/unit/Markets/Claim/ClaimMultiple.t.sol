// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../../../handler/Features/HProcessRewards.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract ClaimMultiple is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    ConvexFxnLPMarket public market2;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HProcessRewards public hRewards2;
    HDepositConvexCrvLP public hDeposit;
    HDepositConvexFxnLP public hDeposit2;

    HBorrow public hBorrow;
    uint256 minimumLoan;

    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployConvexCurveLPMarket(collatToken);
        market2 = deployConvexFxnLPMarket(AddrCurveStableLP.USDC_fxUSD);
        hRewards = new HProcessRewards(usr1, market, rewardAccumulator);
        hRewards2 = new HProcessRewards(usr1, market2, rewardAccumulator);
        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hDeposit2 = new HDepositConvexFxnLP(usr1, market2);
        hBorrow = new HBorrow(usr1, market);
        minimumLoan = market.minimumLoan();
    }

    function test_claimMultiple_with_1_token_in_common() external {
        uint256 collatDeposited = 100_000 ether;

        hDeposit.deposit(usr1, collatDeposited, true);
        hDeposit2.deposit(usr1, collatDeposited, true);

        vm.startPrank(usr1);

        skip(15 days);

        irCalculator.mintIR();
        vm.stopPrank();

        hRewards.processRewards(usr2);
        hRewards2.processRewards(usr2);

        skip(7 days);
        vm.startPrank(usr1);

        rewardAccumulator.claimMultiple(Array.memoryAddress([address(market), address(market2)]), 3);
        rewardAccumulator.claimCutFees(rewardAccumulator.getRewardTokens(address(market)));

        assertLt(rewardAccumulator.rewardTokens(address(market), 0).balanceOf(address(rewardAccumulator)), 10 ** 7);

        vm.stopPrank();
    }

    function test_claimMultiple_with_wrong_reward_len() external {
        uint256 collatDeposited = 100_000 ether;

        hDeposit.deposit(usr1, collatDeposited, true);
        hDeposit2.deposit(usr1, collatDeposited, true);

        vm.startPrank(usr1);

        skip(15 days);

        irCalculator.mintIR();
        vm.stopPrank();

        hRewards.processRewards(usr2);
        hRewards2.processRewards(usr2);

        skip(7 days);
        vm.startPrank(usr1);

        address[] memory marketArrays = Array.memoryAddress([address(market), address(market2)]);

        vm.expectRevert();
        rewardAccumulator.claimMultiple(marketArrays, 2);

        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.IncorrectRewardLength.selector, 4, 3));
        rewardAccumulator.claimMultiple(marketArrays, 4);
    }
}
