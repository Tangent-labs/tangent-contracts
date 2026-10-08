// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../handler/Features/ConvexFxn/HWithdrawConvexFxnLP.sol";
import "../../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../../../handler/Features/HProcessRewards.sol";

contract VolatileFxnEthCvxFxnMarket is MarketDeploymentContext {
    ConvexFxnLPMarket public market;
    IERC20Metadata public collatToken;

    HProcessRewards public hRewards;
    HDepositConvexFxnLP public hDeposit;
    HWithdrawConvexFxnLP public hWithdraw;

    function setUp() public {
        collatToken = AddrCryptoSwapLP.FXN_ETH_LP;
        market = deployConvexFxnLPMarket(collatToken);

        hRewards = new HProcessRewards(usr1, market, rewardAccumulator, usg, marketViewer);
        hDeposit = new HDepositConvexFxnLP(usr1, market, usg, marketViewer);
        hWithdraw = new HWithdrawConvexFxnLP(usr1, market, usg, marketViewer);
    }

    function test_deploy() external view {
        assertTrue(address(market.stakingProxyVault()) != address(0));
        assertGt(market.collatOracle().latestAnswer(false), 0);
        assertTrue(usg.isMinter(address(market)));
        assertTrue(usg.isBurner(address(market)));
    }

    function test_depositBorrow_then_repayWithdraw() external {
        uint256 amountIn = 10_000 ether;
        uint256 borrowedAmount = 5_000 ether;

        hDeposit.depositAndBorrow(amountIn, borrowedAmount, false);
        assertERC20Tracking();

        skip(1 weeks);
        hRewards.processRewards(usr1);

        verifyReceiveERC20(collatToken, usr1, amountIn, "User 1 retrieves its collateral");
        hWithdraw.repayAndWithdraw(amountIn, borrowedAmount, false);

        assertERC20Tracking();
        assertEq(market.collateralBalances(usr1), 0);
    }
}
