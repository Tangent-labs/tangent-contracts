// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

contract wfrxUSD is ConvexCurveContext {
    IERC20 stable = AddrClassicERC20.TOKEN_FRXUSD;
    IERC4626 saving = AddrERC4626.S_FRXUSD;

    function test_mint() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(wfrxUSD), MAX_UINT);
        vm.startSnapshotGas("WStable", "Mint wfrxUSD");
        wfrxUSD.mint(usr1, amountIn, false);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(stable.balanceOf(usr1), 0);
        assertEq(wfrxUSD.balanceOf(usr1), amountIn);

        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(wfrxUSD), MAX_UINT);
        wfrxUSD.mint(usr2, amountIn, false);
        vm.stopPrank();

        assertEq(stable.balanceOf(usr2), 0);
        assertEq(wfrxUSD.balanceOf(usr2), amountIn);
    }

    // function test_burn() external {
    //     vm.startPrank(usr1);
    //     uint256 amountIn = 10_000 ether;
    //     deal(address(stable), usr1, amountIn);
    //     stable.approve(address(wfrxUSD), MAX_UINT);
    //     wfrxUSD.mint(usr1, amountIn, true);
    //     vm.stopPrank();

    //     vm.startPrank(usr2);
    //     deal(address(stable), usr2, amountIn);
    //     stable.approve(address(wfrxUSD), MAX_UINT);
    //     wfrxUSD.mint(usr2, amountIn, true);
    //     vm.stopPrank();

    //     vm.startPrank(usr1);
    //     vm.startSnapshotGas("WStable", "Burn wfrxUSD");
    //     wfrxUSD.burn(usr1, amountIn, false);
    //     vm.stopSnapshotGas();
    //     vm.stopPrank();

    //     assertEq(wfrxUSD.balanceOf(usr1), 0);
    //     assertEq(stable.balanceOf(usr1), amountIn);

    //     vm.startPrank(usr2);
    //     wfrxUSD.burn(usr2, amountIn, false);
    //     vm.stopPrank();

    //     assertEq(wfrxUSD.balanceOf(usr2), 0);
    //     assertEq(stable.balanceOf(usr2), amountIn);
    // }

    // function test_claimRewards_wfrxUSD() external {
    //     vm.startPrank(usr1);
    //     uint256 amountIn = 10_000 ether;
    //     deal(address(stable), usr1, amountIn);
    //     stable.approve(address(wfrxUSD), MAX_UINT);
    //     wfrxUSD.mint(usr1, amountIn, true);

    //     uint256 pps = saving.previewDeposit(1e18);

    //     deal(address(stable), address(saving), stable.balanceOf(address(saving)) + 100_000 ether);
    //     // saving.syncRewardsAndDistribution();
    //     skip(1 weeks);

    //     assertLt(saving.previewDeposit(1e18), pps);

    //     vm.stopPrank();

    //     verifyReceiveERC20(
    //         stable,
    //         feeTreasury,
    //         saving.maxWithdraw(address(wfrxUSD)) - wfrxUSD.totalSupply(),
    //         "Fee Treasury must receive the delta between total withdrawable from saving and totalSupply of tgStable"
    //     );

    //     vm.prank(owner);
    //     wfrxUSD.claimRewards();

    //     assertGe(saving.maxWithdraw(address(wfrxUSD)), amountIn, "User must be able to withdraw its crvUSD");

    //     vm.startPrank(usr1);
    //     wfrxUSD.burn(usr1, amountIn, false);

    //     assertERC20Tracking();
    // }
}
