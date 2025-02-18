// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

contract wDOLA is ConvexCurveContext {
    IERC20 stable = AddrClassicERC20.TOKEN_DOLA;
    IERC4626 saving = AddrERC4626.S_DOLA;

    function test_mint() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(wDOLA), MAX_UINT);
        vm.startSnapshotGas("TgStable", "Mint wDOLA");
        wDOLA.mint(usr1, amountIn, false);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(stable.balanceOf(usr1), 0);
        assertEq(wDOLA.balanceOf(usr1), amountIn);

        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(wDOLA), MAX_UINT);
        wDOLA.mint(usr2, amountIn, false);
        vm.stopPrank();

        assertEq(stable.balanceOf(usr2), 0);
        assertEq(wDOLA.balanceOf(usr2), amountIn);
    }

    // function test_burn() external {
    //     vm.startPrank(usr1);
    //     uint256 amountIn = 10_000 ether;
    //     deal(address(stable), usr1, amountIn);
    //     stable.approve(address(wDOLA), MAX_UINT);
    //     wDOLA.mint(usr1, amountIn, true);
    //     vm.stopPrank();

    //     vm.startPrank(usr2);
    //     deal(address(stable), usr2, amountIn);
    //     stable.approve(address(wDOLA), MAX_UINT);
    //     wDOLA.mint(usr2, amountIn, true);
    //     vm.stopPrank();

    //     vm.startPrank(usr1);
    //     vm.startSnapshotGas("TgStable", "Burn wDOLA");
    //     wDOLA.burn(usr1, amountIn, false);
    //     vm.stopSnapshotGas();
    //     vm.stopPrank();

    //     assertEq(wDOLA.balanceOf(usr1), 0);
    //     assertEq(stable.balanceOf(usr1), amountIn);

    //     vm.startPrank(usr2);
    //     wDOLA.burn(usr2, amountIn, false);
    //     vm.stopPrank();

    //     assertEq(wDOLA.balanceOf(usr2), 0);
    //     assertEq(stable.balanceOf(usr2), amountIn);
    // }

    // function test_claimRewards_wDOLA() external {
    //     vm.startPrank(usr1);
    //     uint256 amountIn = 10_000 ether;
    //     deal(address(stable), usr1, amountIn);
    //     stable.approve(address(wDOLA), MAX_UINT);
    //     wDOLA.mint(usr1, amountIn, true);

    //     uint256 pps = saving.previewDeposit(1e18);

    //     deal(address(stable), address(saving), stable.balanceOf(address(saving)) + 100_000 ether);
    //     // saving.syncRewardsAndDistribution();
    //     skip(1 weeks);

    //     assertLt(saving.previewDeposit(1e18), pps);

    //     vm.stopPrank();

    //     verifyReceiveERC20(
    //         stable,
    //         feeTreasury,
    //         saving.maxWithdraw(address(wDOLA)) - wDOLA.totalSupply(),
    //         "Fee Treasury must receive the delta between total withdrawable from saving and totalSupply of tgStable"
    //     );

    //     vm.prank(owner);
    //     wDOLA.claimRewards();

    //     assertGe(saving.maxWithdraw(address(wDOLA)), amountIn, "User must be able to withdraw its crvUSD");

    //     vm.startPrank(usr1);
    //     wDOLA.burn(usr1, amountIn, false);

    //     assertERC20Tracking();
    // }
}
