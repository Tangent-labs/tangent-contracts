// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract SelfLiquidateStakeDaoVaultV2Market is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;

    StakeDaoVaultV2Market public market;
    IStakeDaoVaultV2 public vaultToken;
    IERC20Metadata public collatToken;

    uint256 borrowedAmount = 5_000 ether;
    uint256 amountIn = 10_000 ether;
    uint256 dumpQuote = 1050 ether;

    function setUp() public {
        vaultToken = AddrStakeDaoVaultV2.USDT_crvUSD_LP;
        collatToken = AddrCurveStableLP.USDT_crvUSD;
        market = deployStakeDaoVaultV2Market(collatToken);

        deal(address(usg), address(zappingProxy), dumpQuote);

        vm.startPrank(usr1);
        vaultToken.approve(address(market), MAX_UINT);
        market.depositAndBorrow(amountIn, borrowedAmount, true);
        vm.stopPrank();
    }

    function test_selfLiquidate_stakeDao_vault_v2__with_isReceipt_to_false() external {
        vm.startPrank(usr1);
        uint256 usgToRepay = 1_000 ether;
        uint256 collatToLiquidate = 1_200 ether;

        //  Verify that gauge token are transfered from user to market directly

        verifyLostERC20(vaultToken, address(market), collatToLiquidate, "Gauge removed from market");
        verifyBurnERC20(usg, usgToRepay, "USG burnt");
        verifyReceiveERC20(usg, usr1, dumpQuote - usgToRepay, "Leftover of USG received by User");

        market.selfLiquidate(
            SelfLiquidateIn({collatAmountToLiquidate: collatToLiquidate, usgToRepay: usgToRepay, maxUsgToBurn: MAX_UINT, minUsgOut: 1_000 ether, isReceiptOut: false}),
            ZapStruct({router: address(usg), routerCall: abi.encodeWithSelector(IERC20.transfer.selector, address(usr1), dumpQuote)})
        );

        assertEq(market.totalCollateral(), amountIn - collatToLiquidate);
        assertEq(market.collateralBalances(usr1), amountIn - collatToLiquidate);
        assertEq(marketViewer.userDebt(market, usr1), borrowedAmount - usgToRepay);
        assertERC20Tracking();

        //  Verify that gauge token are unwrapped to LP and sent to user
        verifyLostERC20(vaultToken, address(market), market.totalCollateral(), "Gauge transfered from Market");
        verifyReceiveERC20(vaultToken, usr1, amountIn - collatToLiquidate, "Gauge received by User 1");

        verifyLostERC20(vaultToken, address(market), market.totalCollateral(), "USG burnt");
        verifyBurnERC20(usg, marketViewer.userDebt(market, usr1), "USG burnt from usr1");

        market.repayAndWithdraw(market.totalCollateral(), MAX_UINT, true);
        assertEq(market.totalCollateral(), 0);
        assertEq(market.collateralBalances(usr1), 0);
        assertERC20Tracking();
    }

    function test_selfLiquidate_stakeDao_vault_v2__with_isReceipt_to_true() external {
        vm.startPrank(usr1);
        uint256 usgToRepay = 1_000 ether;
        uint256 collatToLiquidate = 1_200 ether;

        //  Verify that gauge token are transfered from user to market directly

        verifyLostERC20(vaultToken, address(market), collatToLiquidate, "Gauge removed from market");
        verifyBurnERC20(usg, usgToRepay, "USG burnt");
        verifyReceiveERC20(usg, usr1, dumpQuote - usgToRepay, "Leftover of USG received by User");

        market.selfLiquidate(
            SelfLiquidateIn({collatAmountToLiquidate: collatToLiquidate, usgToRepay: usgToRepay, maxUsgToBurn: MAX_UINT, minUsgOut: 1_000 ether, isReceiptOut: true}),
            ZapStruct({router: address(usg), routerCall: abi.encodeWithSelector(IERC20.transfer.selector, address(usr1), dumpQuote)})
        );

        assertEq(market.totalCollateral(), amountIn - collatToLiquidate);
        assertEq(market.collateralBalances(usr1), amountIn - collatToLiquidate);
        assertEq(marketViewer.userDebt(market, usr1), borrowedAmount - usgToRepay);
        assertERC20Tracking();

        //  Verify that gauge token are unwrapped to LP and sent to user
        verifyLostERC20(vaultToken, address(market), market.totalCollateral(), "Gauge transfered from Market");
        verifyReceiveERC20(vaultToken, usr1, amountIn - collatToLiquidate, "Gauge received by User 1");

        verifyLostERC20(vaultToken, address(market), market.totalCollateral(), "USG burnt");
        verifyBurnERC20(usg, marketViewer.userDebt(market, usr1), "USG burnt from usr1");

        market.repayAndWithdraw(market.totalCollateral(), MAX_UINT, true);
        assertEq(market.totalCollateral(), 0);
        assertEq(market.collateralBalances(usr1), 0);
        assertERC20Tracking();
    }
}
