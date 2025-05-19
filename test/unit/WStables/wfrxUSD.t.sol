// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract wfrxUSD is MarketDeploymentContext {
    IERC20 stable = AddrClassicERC20.frxUSD;
    IERC4626 saving = AddrERC4626.sfrxUSD;

    function test_mint_wfrxUSD() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(wfrxUSD), MAX_UINT);
        vm.startSnapshotGas("WStable", "Mint wfrxUSD");
        wfrxUSD.mint(amountIn, usr1, false);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(stable.balanceOf(usr1), 0);
        assertEq(wfrxUSD.balanceOf(usr1), amountIn);

        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(wfrxUSD), MAX_UINT);
        wfrxUSD.mint(amountIn, usr2, false);
        vm.stopPrank();

        assertEq(stable.balanceOf(usr2), 0);
        assertEq(wfrxUSD.balanceOf(usr2), amountIn);
    }

    function test_burn_wfrxUSD() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(wfrxUSD), MAX_UINT);
        wfrxUSD.mint(amountIn, usr1, false);
        vm.stopPrank();

        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(wfrxUSD), MAX_UINT);
        wfrxUSD.mint(amountIn, usr2, false);
        vm.stopPrank();

        vm.startPrank(usr1);
        vm.startSnapshotGas("WStable", "Burn wfrxUSD");
        wfrxUSD.burn(amountIn, usr1, false);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(wfrxUSD.balanceOf(usr1), 0);
        assertEq(stable.balanceOf(usr1), amountIn);

        vm.startPrank(usr2);
        wfrxUSD.burn(amountIn, usr2, false);
        vm.stopPrank();

        assertEq(wfrxUSD.balanceOf(usr2), 0);
        assertEq(stable.balanceOf(usr2), amountIn);
    }

    function test_claimRewards_wfrxUSD() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(wfrxUSD), MAX_UINT);
        wfrxUSD.mint(amountIn, usr1, false);

        uint256 pps = saving.previewDeposit(1e18);

        deal(address(stable), address(saving), stable.balanceOf(address(saving)) + 100_000 ether);
        // saving.syncRewardsAndDistribution();
        skip(1 weeks);

        assertLt(saving.previewDeposit(1e18), pps);

        vm.stopPrank();

        verifyReceiveERC20(
            stable,
            feeTreasury,
            saving.maxWithdraw(address(wfrxUSD)) - wfrxUSD.totalSupply(),
            "Fee Treasury must receive the delta between total withdrawable from saving and totalSupply of tgStable"
        );

        vm.prank(owner);
        wfrxUSD.claimRewards();

        assertGe(saving.maxWithdraw(address(wfrxUSD)), amountIn, "User must be able to withdraw its crvUSD");

        vm.startPrank(usr1);
        wfrxUSD.burn(amountIn, usr1, false);

        assertERC20Tracking();
    }
}
