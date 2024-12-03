// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

contract TgFRAX is ConvexCurveContext {
    IERC20 stable = AddrClassicERC20.TOKEN_FRAX;
    ISFRAX saving = AddrERC4626.S_FRAX;

    function test_mint() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(tgFRAX), MAX_UINT);
        vm.startSnapshotGas("TgStable", "Mint tgFRAX");
        tgFRAX.mint(usr1, amountIn, true);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(stable.balanceOf(usr1), 0);
        assertEq(tgFRAX.balanceOf(usr1), amountIn);

        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(tgFRAX), MAX_UINT);
        tgFRAX.mint(usr2, amountIn, true);
        vm.stopPrank();

        assertEq(stable.balanceOf(usr2), 0);
        assertEq(tgFRAX.balanceOf(usr2), amountIn);
    }

    function test_burn() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(tgFRAX), MAX_UINT);
        tgFRAX.mint(usr1, amountIn, true);
        vm.stopPrank();

        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(tgFRAX), MAX_UINT);
        tgFRAX.mint(usr2, amountIn, true);
        vm.stopPrank();

        vm.startPrank(usr1);
        vm.startSnapshotGas("TgStable", "Burn tgFRAX");
        tgFRAX.burn(usr1, amountIn);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(tgFRAX.balanceOf(usr1), 0);
        assertEq(stable.balanceOf(usr1), amountIn);

        vm.startPrank(usr2);
        tgFRAX.burn(usr2, amountIn);
        vm.stopPrank();

        assertEq(tgFRAX.balanceOf(usr2), 0);
        assertEq(stable.balanceOf(usr2), amountIn);
    }

    function test_claimRewards_tgFRAX() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(tgFRAX), MAX_UINT);
        tgFRAX.mint(usr1, amountIn, true);

        uint256 pps = saving.previewDeposit(1e18);

        deal(address(stable), address(saving), stable.balanceOf(address(saving)) + 100_000 ether);
        saving.syncRewardsAndDistribution();
        skip(1 weeks);

        assertLt(saving.previewDeposit(1e18), pps);

        vm.stopPrank();

        verifyReceiveERC20(
            stable,
            feeTreasury,
            saving.maxWithdraw(address(tgFRAX)) - tgFRAX.totalSupply(),
            "Fee Treasury must receive the delta between total withdrawable from saving and totalSupply of tgStable"
        );

        vm.prank(owner);
        tgFRAX.claimRewards();

        assertGe(saving.maxWithdraw(address(tgFRAX)), amountIn, "User must be able to withdraw its crvUSD");

        vm.startPrank(usr1);
        tgFRAX.burn(usr1, amountIn);

        assertERC20Tracking();
    }
}
