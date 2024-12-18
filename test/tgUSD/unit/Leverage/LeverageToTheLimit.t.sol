// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";
import "../../handler/Features/BorrowRepay/HBorrow.sol";

contract LeverageToTheLimit is ConvexCurveContext {
    ConvexFxnLPMarket public market;
    IERC20Metadata public collatToken;

    uint256 minimumLoan;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_FXUSD;
        market = deployConvexFxnLPMarket(collatToken);

        minimumLoan = market.minimumLoan();
    }

    function test_leverage_to_limit() external {
        uint256 collatToDeposit = 10_000 ether;
        uint256 tgUSDToFlashMint = 20_000 ether;
        uint256 minCollatReceived = 19_000 ether;

        uint256 quote = odosUtils.getQuoteOdos(tgUSDToFlashMint, AddrClassicERC20.TOKEN_USDC, collatToken, usr1);

        vm.mockFunction(address(AddrAggregator.ODOS_ROUTER), address(mockEnsoRouterRepay), abi.encodeWithSelector(IOdosRouter.swapCompact.selector));

        market.leverage(
            collatToDeposit,
            tgUSDToFlashMint,
            minCollatReceived,
            address(zapper),
            true,
            abi.encodeWithSelector(IOdosRouter.swapCompact.selector, address(tgUsd), address(collatToken), usr1, mockedLP, tgUSDToFlashMint, quote)
        );

        uint256 withdrawnAmount = 1_000 ether;

        // // verifyLostERC20(market.cvxRewardToken(), address(market), withdrawnAmount, "Verify that market receives Cvx Reward tokens");
        // // verifyBurnERC20(market.cvxRewardToken(), withdrawnAmount, "Verify that Cvx Reward tokens are burnt");
        // verifyReceiveERC20(collatToken, usr1, withdrawnAmount, "Verify that user 1 retrieve its collateral");

        // vm.startSnapshotGas("Withdraw", "Withdraw fully from staked collat");
        // hWithdraw.withdraw(withdrawnAmount);
        // vm.stopSnapshotGas();

        // assertERC20Tracking();
    }
}
