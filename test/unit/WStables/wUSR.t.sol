// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract wUSR is MarketDeploymentContext {
    IERC20 stable = AddrClassicERC20.USR;
    IERC4626 saving = AddrERC4626.wstUSR;
    IERC20 stUSR = AddrClassicERC20.stUSR;

    function test_mint_wUSR_with_USR() external {
        uint256 amountIn = 10_000 ether;

        // Mint with usr1 with USR
        vm.startPrank(usr1);
        deal(address(stable), usr1, amountIn);
        stable.approve(address(wUSR), MAX_UINT);
        vm.startSnapshotGas("WStable", "Mint wUSR with USR");
        wUSR.mint(amountIn, usr1, false);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(stable.balanceOf(usr1), 0);
        assertEq(wUSR.balanceOf(usr1), amountIn);

        // Mint with usr2 with USR
        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(wUSR), MAX_UINT);
        wUSR.mint(amountIn, usr2, false);
        vm.stopPrank();

        assertEq(stable.balanceOf(usr2), 0);
        assertEq(wUSR.balanceOf(usr2), amountIn);
    }

    function test_deposit_USR_to_wUSR_with_deposit() external {
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        deal(address(stable), usr2, amountIn);
        // Mint with usr1 with USR
        vm.startPrank(usr1);
        stable.approve(address(wUSR), MAX_UINT);

        verifyLostERC20(stable, usr1, amountIn, "User 1 deposit and so, lost his USR");
        verifyReceiveERC20(wUSR, usr1, amountIn, "User 1 receives the same amount of wUSR");

        vm.startSnapshotGas("WStable", "Deposit USR to wUSR");
        wUSR.deposit(amountIn, usr1);

        vm.stopSnapshotGas();
        assertERC20Tracking();

        assertEq(stable.balanceOf(usr1), 0);
        assertEq(wUSR.balanceOf(usr1), amountIn);

        vm.stopPrank();

        // Mint with usr2 with USR and put usr1 as receiver
        vm.startPrank(usr2);
        stable.approve(address(wUSR), MAX_UINT);

        verifyLostERC20(stable, usr2, amountIn, "User 2 deposit and so, lost his USR");
        verifyReceiveERC20(wUSR, usr1, amountIn, "User 1 receives wUSR because he is in receiver");

        wUSR.deposit(amountIn, usr1);
        assertEq(stable.balanceOf(usr2), 0);
        assertEq(wUSR.balanceOf(usr2), 0);
        assertEq(wUSR.balanceOf(usr1), 2 * amountIn);
        vm.stopPrank();
    }

    function test_mint_wUSR_with_sUSR() external {
        uint256 amountIn = 10_000 ether;

        // Mint with usr1 with USR

        uint256 expectedwUSR = saving.convertToAssets(amountIn);
        vm.startPrank(usr1);
        deal(address(saving), usr1, amountIn);
        saving.approve(address(wUSR), MAX_UINT);
        vm.startSnapshotGas("WStable", "Mint wUSR with sUSR");
        wUSR.mint(amountIn, usr1, true);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(saving.balanceOf(usr1), 0);
        assertEq(wUSR.balanceOf(usr1), expectedwUSR);
    }

    function test_burn_wUSR() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(wUSR), MAX_UINT);
        wUSR.mint(amountIn, usr1, false);
        vm.stopPrank();

        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(wUSR), MAX_UINT);
        wUSR.mint(amountIn, usr2, false);
        vm.stopPrank();

        vm.startPrank(usr1);
        vm.startSnapshotGas("WStable", "Burn wUSR to USR");
        wUSR.burn(amountIn, usr1, false);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(wUSR.balanceOf(usr1), 0);
        assertEq(stable.balanceOf(usr1), amountIn);

        uint256 expectedSavingOut = saving.convertToShares(amountIn);
        vm.startPrank(usr2);
        vm.startSnapshotGas("WStable", "Burn wUSR to sUSR");
        wUSR.burn(amountIn, usr2, true);
        vm.stopSnapshotGas();

        vm.stopPrank();

        assertEq(wUSR.balanceOf(usr2), 0);
        assertEq(saving.balanceOf(usr2), expectedSavingOut);
    }

    function test_redeem_wUSR_to_USR() external {
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);

        vm.startPrank(usr1);

        stable.approve(address(wUSR), MAX_UINT);
        wUSR.mint(amountIn, usr1, false);

        verifyBurnERC20(wUSR, amountIn, "wUSR burnt");
        verifyLostERC20(wUSR, usr1, amountIn, "wUSR lost by usr1");
        verifyReceiveERC20(stable, usr2, amountIn, "USR redeemed by usr1 on usr2");

        wUSR.redeem(amountIn, usr2, owner);

        assertERC20Tracking();
    }

    function test_mint_fails_if_zero_amount() external {
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);

        vm.startPrank(usr1);

        stable.approve(address(wUSR), MAX_UINT);

        vm.expectRevert(abi.encodeWithSelector(WStable.ZeroAmount.selector));
        wUSR.mint(0, usr1, false);
    }

    function test_burn_fails_if_zero_amount() external {
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);

        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(WStable.ZeroAmount.selector));
        wUSR.burn(0, usr1, false);
    }

    function test_claimRewards_fails_if_nothing_to_claim() external {
        vm.expectRevert(abi.encodeWithSelector(WStable.NoRewardsToClaim.selector));
        wUSR.claimRewards();
    }

    function test_convert_views() external view {
        uint256 amount = 100;
        assertEq(wUSR.convertToAssets(amount), amount);
        assertEq(wUSR.convertToShares(amount), amount);
    }

    function test_claimRewards_wUSR() external {
        uint256 amountToDistribute = 3_000_000 ether;
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountToDistribute + amountIn);

        vm.startPrank(usr1);

        stable.approve(address(wUSR), MAX_UINT);
        wUSR.mint(amountIn, usr1, false);

        uint256 pps = saving.previewMint(1e18);

        // Simulate a reward distribution ( increase the index )
        stable.transfer(address(stUSR), amountToDistribute - amountIn);
        skip(1 weeks);

        assertLt(pps, saving.previewMint(1e18));

        vm.stopPrank();

        verifyReceiveERC20(
            wUSR,
            feeTreasury,
            saving.maxWithdraw(address(wUSR)) - wUSR.totalSupply(),
            "Fee Treasury must receive the delta between total withdrawable from saving and totalSupply of tgStable"
        );

        vm.prank(owner);
        wUSR.claimRewards();

        assertGe(saving.maxWithdraw(address(wUSR)), amountIn, "User must be able to withdraw its crvUSD");

        vm.startPrank(usr1);
        wUSR.burn(amountIn, usr1, false);

        assertERC20Tracking();
    }
}
