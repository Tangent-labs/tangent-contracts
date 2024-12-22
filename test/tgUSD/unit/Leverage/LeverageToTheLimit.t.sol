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
        vm.startPrank(usr1);
        uint256 collatToDeposit = 10_000 ether;
        uint256 tgUSDToFlashMint = 20_000 ether;
        uint256 collatReceived = 19_000 ether;

        vm.mockFunction(address(AddrAggregator.ENSO_ROUTER), address(mockEnsoRouter), abi.encodeWithSelector(IEnsoRouter.routeSingle.selector));

        collatToken.approve(address(market), MAX_UINT);
        deal(address(collatToken), usr1, collatToDeposit);

        market.leverage(
            collatToDeposit,
            tgUSDToFlashMint,
            collatReceived,
            address(zapper),
            true,
            abi.encodeWithSelector(
                IEnsoRouter.routeSingle.selector,
                address(tgUsd),
                tgUSDToFlashMint,
                Array.memoryBytes32(
                    [
                        addressToBytes32(address(collatToken)),
                        addressToBytes32(mockedLP),
                        addressToBytes32(address(market)),
                        addressToBytes32(address(zapper)),
                        bytes32(collatReceived)
                    ]
                ),
                new bytes[](0)
            )
        );

        assertEq(market.collateralBalances(usr1), collatToDeposit + collatReceived);
        assertEq(market.totalCollateral(), collatToDeposit + collatReceived);
        assertEq(market.positionDebt(usr1), tgUSDToFlashMint);

        // // verifyLostERC20(market.cvxRewardToken(), address(market), withdrawnAmount, "Verify that market receives Cvx Reward tokens");
        // // verifyBurnERC20(market.cvxRewardToken(), withdrawnAmount, "Verify that Cvx Reward tokens are burnt");
        // verifyReceiveERC20(collatToken, usr1, withdrawnAmount, "Verify that user 1 retrieve its collateral");

        // vm.startSnapshotGas("Withdraw", "Withdraw fully from staked collat");
        // hWithdraw.withdraw(withdrawnAmount);
        // vm.stopSnapshotGas();

        // assertERC20Tracking();
    }
}
