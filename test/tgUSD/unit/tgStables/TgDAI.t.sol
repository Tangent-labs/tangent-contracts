// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

contract TgDAI is ConvexCurveContext {
    IERC20 stable = AddrClassicERC20.TOKEN_DAI;
    IERC4626 saving = AddrERC4626.S_DAI;

    function test_mint() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(tgDAI), MAX_UINT);
        vm.startSnapshotGas("TgStable", "Mint tgDAI");
        tgDAI.mint(usr1, amountIn, true);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(stable.balanceOf(usr1), 0);
        assertEq(tgDAI.balanceOf(usr1), amountIn);

        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(tgDAI), MAX_UINT);
        tgDAI.mint(usr2, amountIn, true);
        vm.stopPrank();

        assertEq(stable.balanceOf(usr2), 0);
        assertEq(tgDAI.balanceOf(usr2), amountIn);
    }

    function test_burn() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(tgDAI), MAX_UINT);
        tgDAI.mint(usr1, amountIn, true);
        vm.stopPrank();

        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(tgDAI), MAX_UINT);
        tgDAI.mint(usr2, amountIn, true);
        vm.stopPrank();

        vm.startPrank(usr1);
        vm.startSnapshotGas("TgStable", "Burn tgDAI");
        tgDAI.burn(usr1, amountIn);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(tgDAI.balanceOf(usr1), 0);
        assertEq(stable.balanceOf(usr1), amountIn);

        vm.startPrank(usr2);
        tgDAI.burn(usr2, amountIn);
        vm.stopPrank();

        assertEq(tgDAI.balanceOf(usr2), 0);
        assertEq(stable.balanceOf(usr2), amountIn);
    }

    function test_claimRewards_tgDAI() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(tgDAI), MAX_UINT);
        tgDAI.mint(usr1, amountIn, true);

        uint256 pps = saving.previewDeposit(1e18);

        deal(address(stable), address(saving), stable.balanceOf(address(saving)) + 100_000 ether);

        skip(1 weeks);

        assertLt(saving.previewDeposit(1e18), pps);

        vm.stopPrank();

        verifyReceiveERC20(
            stable,
            feeTreasury,
            saving.maxWithdraw(address(tgDAI)) - tgDAI.totalSupply(),
            "Fee Treasury must receive the delta between total withdrawable from saving and totalSupply of tgStable"
        );

        vm.prank(owner);
        tgDAI.claimRewards();

        assertGe(saving.maxWithdraw(address(tgDAI)), amountIn, "User must be able to withdraw its crvUSD");

        vm.startPrank(usr1);
        tgDAI.burn(usr1, amountIn);

        assertERC20Tracking();
    }
}
