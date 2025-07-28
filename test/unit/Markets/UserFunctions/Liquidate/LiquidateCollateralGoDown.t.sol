// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";
import "../../../../utils/ERC20BalanceChanges.sol";

import "../../../../handler/Curve/HLPManipulator.sol";
import "../../../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../../handler/Features/HProcessRewards.sol";

contract LiquidateCollateralGoDown is MarketDeploymentContext {
    ConvexFxnLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexFxnLP public hDeposit;
    HBorrow public hBorrow;
    HLPManipulator public hLpManipulator;

    ERC20BalanceChanges public balanceChanges;

    uint256 collatDeposited = 10_000 ether;
    uint256 USGBorrowed = 8_000 ether;

    IERC20[] rewardTokens;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_fxUSD;
        market = deployConvexFxnLPMarket(collatToken);

        hDeposit = new HDepositConvexFxnLP(usr1, market);
        hBorrow = new HBorrow(usr1, market);
        hLpManipulator = new HLPManipulator(usr1);

        hDeposit.depositAndBorrow(collatDeposited, USGBorrowed);

        hDeposit.setMsgSender(usr2);
        hDeposit.depositAndBorrow(collatDeposited, USGBorrowed);
        hDeposit.setMsgSender(usr3);
        hDeposit.depositAndBorrow(collatDeposited, USGBorrowed);

        balanceChanges = new ERC20BalanceChanges();

        rewardTokens = rewardAccumulator.getRewardTokens(address(market));
    }

    function test_liquidate_all_after_collateral_loses_value() external {
        // Liquidation shoudn't pass as HR is ok
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(usr1, collatDeposited, 0, ZapStruct({router: address(0), routerCall: ""}));
        vm.stopPrank();

        // Unbalance USDC_FXUSD LP for destroying the peg and so the price_oracle
        hLpManipulator.dumpCrvPool(AddrCurveStableLP.USDC_fxUSD, 1, 0, 9_000_000 ether);

        vm.startPrank(usr1);
        // Liquidation doesn't pass because price_oracle is not updated yet
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(usr1, collatDeposited, 0, ZapStruct({router: address(0), routerCall: ""}));

        (uint128 lastUpdateTime, uint256 periodFinish, uint256 rewardRate, uint256 rewardPerTokenStored) = rewardAccumulator.rewardData(address(market), rewardTokens[0]);
        assertEq(lastUpdateTime, periodFinish, "Times are the same as on deployment because no processRewards occured");
        assertEq(rewardRate, 0, "Reward rate should be 0 before processRewards");
        assertEq(rewardRate, rewardPerTokenStored, "RewardPerTokenStored should be 0 before processRewards");
        skip(200);

        uint256 userDebt = market.userDebt(usr1);
        uint256 liquidationFee = (userDebt * market.liquidationFee()) / 100_000;
        deal(address(usg), usr1, userDebt + liquidationFee);

        verifyLostERC20(usg, usr1, userDebt + liquidationFee, "USG burnt from sender");
        verifyReceiveERC20(usg, feeTreasury, liquidationFee, "USG fee are minted on the treasury");

        verifyReceiveERC20(collatToken, usr1, market.collateralBalances(usr1), "USG burnt from sender");

        // Liquidation passes after EMA of price_oralce passed
        market.liquidate(usr1, collatDeposited, 0, ZapStruct({router: address(0), routerCall: ""}));

        assertERC20Tracking();
        (lastUpdateTime, periodFinish, rewardRate, rewardPerTokenStored) = rewardAccumulator.rewardData(address(market), rewardTokens[0]);
        assertEq(lastUpdateTime, periodFinish, "Times are the same as on deployment because no processRewards occured");
        assertEq(rewardRate, 0, "Reward rate should be 0 before processRewards");
        assertEq(rewardRate, rewardPerTokenStored, "RewardPerTokenStored should be 0 before processRewards");

        uint256 pendingInterests = irCalculator.mintableInterests();
        assertEq(market.userDebt(usr1), 0);
        assertEq(market.totalDebt(), USGBorrowed * 2 + ((pendingInterests * 2) / 3), "Total debt wrong");

        (uint216 ir, uint40 timestamp) = irCalculator.irCheckpoints(address(market));

        assertEq(ir, uint256(irCalculator.getIRParams(address(market)).rMin) * 1e13);

        skip(1 days);

        vm.stopPrank();
        uint256 timestampAtProcessRewards = block.timestamp;

        deal(address(AddrClassicERC20.FXN), address(market), 1_000 ether);
        rewardAccumulator.processRewards(address(market), usr1);

        (lastUpdateTime, periodFinish, rewardRate, rewardPerTokenStored) = rewardAccumulator.rewardData(address(market), rewardTokens[0]);

        assertEq(lastUpdateTime, timestampAtProcessRewards, "Initialized thanks to processRewards");
        assertEq(periodFinish, timestampAtProcessRewards + 1 weeks, "Initialized thanks to processRewards");

        skip(7 days);

        (lastUpdateTime, periodFinish, rewardRate, rewardPerTokenStored) = rewardAccumulator.rewardData(address(market), rewardTokens[0]);

        balanceChanges.trackReceiveERC20(usr2, rewardTokens);
        vm.prank(usr2);
        rewardAccumulator.claimSimple(address(market));

        balanceChanges.trackReceiveERC20(usr3, rewardTokens);
        vm.prank(usr3);
        rewardAccumulator.claimSimple(address(market));

        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.NoRewardToSimpleClaim.selector));
        vm.prank(usr1);
        rewardAccumulator.claimSimple(address(market));

        TokenAmount[] memory receiveUser2 = balanceChanges.getReceivedERC20(usr2);
        TokenAmount[] memory receivedUser3 = balanceChanges.getReceivedERC20(usr3);

        assertTrue(balanceChanges.areTokenAmountsArrayEquals(receiveUser2, receivedUser3));

        TokenAmount[] memory rewardAccBalances = balanceChanges.getErc20Balances(address(rewardAccumulator), rewardTokens);

        for (uint256 index = 0; index < rewardTokens.length; index++) {
            IERC20 token = rewardTokens[index];
            uint256 fee = rewardAccumulator.cutFeeForToken(token);
            uint256 balLeft = rewardAccBalances[index].amount;

            assertApproxEqRel(fee, balLeft, 1e12, "Should be almost equal, there is a lost in precision on reward streaming");

            verifyLostERC20(token, address(rewardAccumulator), fee, "Send fee treasury");
            verifyReceiveERC20(token, feeTreasury, fee, "Receive fee treasury");
        }

        rewardAccumulator.claimCutFees(rewardTokens);

        assertERC20Tracking();

        vm.stopPrank();
    }

    function test_liquidate_partial_after_collateral_loses_value() external {
        // Liquidation shoudn't pass as HR is ok
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(usr1, collatDeposited, 0, ZapStruct({router: address(0), routerCall: ""}));
        vm.stopPrank();

        // Unbalance USDC_FXUSD LP for destroying the peg and so the price_oracle
        hLpManipulator.dumpCrvPool(AddrCurveStableLP.USDC_fxUSD, 1, 0, 9_000_000 ether);

        vm.startPrank(usr1);
        // Liquidation doesn't pass because price_oracle is not updated yet
        vm.expectRevert(abi.encodeWithSelector(MarketCore.NotLiquidablePosition.selector));
        market.liquidate(usr1, collatDeposited, 0, ZapStruct({router: address(0), routerCall: ""}));

        vm.stopPrank();

        skip(200);

        vm.startPrank(usr1);

        uint256 userDebt = market.userDebt(usr1);
        uint256 debtToRepay = userDebt / 2;
        uint256 liquidationFee = (debtToRepay * market.liquidationFee()) / 100_000;

        deal(address(usg), usr1, 2 * userDebt);

        verifyLostERC20(usg, usr1, (debtToRepay + liquidationFee), "USG burnt from sender");
        verifyReceiveERC20(usg, feeTreasury, liquidationFee, "USG received by the treasuryFee");

        verifyReceiveERC20(collatToken, usr1, 5_000 ether, "Collat sent to liquidator");

        // Liquidation doesn't pass because 0 collat is passed in param
        vm.expectRevert(abi.encodeWithSelector(Collateral.ZeroCollatAmount.selector));
        market.liquidate(usr1, 0, 0, ZapStruct({router: address(0), routerCall: ""}));

        // Liquidation passes after EMA of price_oralce passed
        market.liquidate(usr1, 5_000 ether, 0, ZapStruct({router: address(0), routerCall: ""}));

        assertERC20Tracking();

        assertEq(market.userDebt(usr1), userDebt - debtToRepay);
        assertEq(market.totalDebt(), market.userDebt(usr1) + market.userDebt(usr2) + market.userDebt(usr3), "Total Debt");

        (uint216 ir, uint40 timestamp) = irCalculator.irCheckpoints(address(market));

        assertEq(ir, uint256(irCalculator.getIRParams(address(market)).rMin) * 1e13, "IR is at the minimum");

        uint256 collatToLiquidate = 100;
        verifyLostERC20(usg, usr1, 81, "USG burnt from sender");
        verifyReceiveERC20(usg, feeTreasury, 1, "USG received by the treasuryFee");

        verifyReceiveERC20(collatToken, usr1, collatToLiquidate, "Collat sent to liquidator");

        market.liquidate(usr1, collatToLiquidate, 0, ZapStruct({router: address(0), routerCall: ""}));
        assertERC20Tracking();

        userDebt = market.userDebt(usr1);
        liquidationFee = (userDebt * market.liquidationFee()) / 100_000;

        verifyLostERC20(usg, usr1, userDebt + liquidationFee, "USG burnt from sender");
        verifyReceiveERC20(usg, feeTreasury, liquidationFee, "USG received by the treasuryFee");

        verifyReceiveERC20(collatToken, usr1, market.collateralBalances(usr1), "Collat sent to liquidator");

        // Try to liquidate and leave a loan with less than the minimumLoan

        uint256 collatBalances = market.collateralBalances(usr1);
        vm.expectRevert(abi.encodeWithSelector(DebtIR.UserDebtTooLow.selector));
        market.liquidate(usr1, collatBalances - 1 ether, 0, ZapStruct({router: address(0), routerCall: ""}));

        market.liquidate(usr1, collatBalances, 0, ZapStruct({router: address(0), routerCall: ""}));
        assertERC20Tracking();

        vm.stopPrank();
    }
}
