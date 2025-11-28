// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract wDOLA is MarketDeploymentContext {
    IERC20 stable = AddrClassicERC20.DOLA;
    IERC4626 saving = AddrERC4626.sDOLA;

    function test_mint_wDOLA_with_DOLA() external {
        uint256 amountIn = 10_000 ether;

        // Mint with usr1 with DOLA
        vm.startPrank(usr1);
        deal(address(stable), usr1, amountIn);
        stable.approve(address(wDOLA), MAX_UINT);
        vm.startSnapshotGas("WStable", "Mint wDOLA with DOLA");
        wDOLA.mint(amountIn, usr1, false);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(stable.balanceOf(usr1), 0);
        assertEq(wDOLA.balanceOf(usr1), amountIn);

        // Mint with usr2 with DOLA
        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(wDOLA), MAX_UINT);
        wDOLA.mint(amountIn, usr2, false);
        vm.stopPrank();

        assertEq(stable.balanceOf(usr2), 0);
        assertEq(wDOLA.balanceOf(usr2), amountIn);
    }

    function test_deposit_DOLA_to_wDOLA_with_deposit() external {
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        deal(address(stable), usr2, amountIn);
        // Mint with usr1 with DOLA
        vm.startPrank(usr1);
        stable.approve(address(wDOLA), MAX_UINT);

        verifyLostERC20(stable, usr1, amountIn, "User 1 deposit and so, lost his DOLA");
        verifyReceiveERC20(wDOLA, usr1, amountIn, "User 1 receives the same amount of wDOLA");

        vm.startSnapshotGas("WStable", "Deposit DOLA to wDOLA");
        wDOLA.deposit(amountIn, usr1);

        vm.stopSnapshotGas();
        assertERC20Tracking();

        assertEq(stable.balanceOf(usr1), 0);
        assertEq(wDOLA.balanceOf(usr1), amountIn);

        vm.stopPrank();

        // Mint with usr2 with DOLA and put usr1 as receiver
        vm.startPrank(usr2);
        stable.approve(address(wDOLA), MAX_UINT);

        verifyLostERC20(stable, usr2, amountIn, "User 2 deposit and so, lost his DOLA");
        verifyReceiveERC20(wDOLA, usr1, amountIn, "User 1 receives wDOLA because he is in receiver");

        wDOLA.deposit(amountIn, usr1);
        assertEq(stable.balanceOf(usr2), 0);
        assertEq(wDOLA.balanceOf(usr2), 0);
        assertEq(wDOLA.balanceOf(usr1), 2 * amountIn);
        vm.stopPrank();
    }

    function test_mint_wDOLA_with_sDOLA() external {
        uint256 amountIn = 10_000 ether;

        // Mint with usr1 with DOLA

        uint256 expectedWDola = saving.convertToAssets(amountIn);
        vm.startPrank(usr1);
        deal(address(saving), usr1, amountIn);
        saving.approve(address(wDOLA), MAX_UINT);
        vm.startSnapshotGas("WStable", "Mint wDOLA with sDOLA");
        wDOLA.mint(amountIn, usr1, true);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(saving.balanceOf(usr1), 0);
        assertEq(wDOLA.balanceOf(usr1), expectedWDola);
    }

    function test_burn_wDOLA() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(wDOLA), MAX_UINT);
        wDOLA.mint(amountIn, usr1, false);
        vm.stopPrank();

        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(wDOLA), MAX_UINT);
        wDOLA.mint(amountIn, usr2, false);
        vm.stopPrank();

        vm.startPrank(usr1);
        vm.startSnapshotGas("WStable", "Burn wDOLA to DOLA");
        wDOLA.burn(amountIn, usr1, false);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(wDOLA.balanceOf(usr1), 0);
        assertEq(stable.balanceOf(usr1), amountIn);

        uint256 expectedSavingOut = saving.previewWithdraw(amountIn);
        vm.startPrank(usr2);
        vm.startSnapshotGas("WStable", "Burn wDOLA to sDOLA");
        wDOLA.burn(amountIn, usr2, true);
        vm.stopSnapshotGas();

        vm.stopPrank();

        assertEq(wDOLA.balanceOf(usr2), 0);
        assertApproxEqAbs(saving.balanceOf(usr2), expectedSavingOut, 1, "Saving out expected");
    }

    function test_claimRewards_wDOLA() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(wDOLA), MAX_UINT);
        wDOLA.mint(amountIn, usr1, false);

        uint256 pps = saving.previewMint(1e18);

        deal(address(stable), address(saving), stable.balanceOf(address(saving)) + 100_000 ether);
        // saving.syncRewardsAndDistribution();
        skip(1 weeks);

        assertLt(pps, saving.previewMint(1e18));

        vm.stopPrank();

        verifyReceiveERC20(
            wDOLA,
            feeTreasury,
            saving.maxWithdraw(address(wDOLA)) - wDOLA.totalSupply(),
            "Fee Treasury must receive the delta between total withdrawable from saving and totalSupply of tgStable"
        );

        vm.prank(owner);
        wDOLA.claimRewards();

        assertGe(saving.maxWithdraw(address(wDOLA)), amountIn, "User must be able to withdraw its crvUSD");

        vm.startPrank(usr1);
        wDOLA.burn(amountIn, usr1, false);

        assertERC20Tracking();
    }
}
