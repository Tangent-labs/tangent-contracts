// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

contract TgDOLA is ConvexCurveContext {
    IERC20 stable = AddrClassicERC20.TOKEN_DOLA;
    IERC4626 saving = AddrERC4626.S_DOLA;
    uint256 amountIn = 10_000 ether * 3333333;

    uint256 initialDonation = 1 ether;

    uint256 donationShare;

    function setUp() public {
        tgDOLA = new TgStable("tgDOLA", "tgDOLA", controlTower, AddrClassicERC20.TOKEN_DOLA, AddrERC4626.S_DOLA, owner, socFeePercentage);
        deal(address(stable), owner, initialDonation);
        vm.startPrank(owner);
        stable.approve(address(tgDOLA), MAX_UINT);
        tgDOLA.mint(owner, initialDonation, true);
        vm.stopPrank();

        donationShare = saving.balanceOf(address(tgDOLA));
    }

    function test_mint_with_stake() external {
        vm.startPrank(usr1);
        deal(address(stable), usr1, amountIn);
        stable.approve(address(tgDOLA), MAX_UINT);
        vm.startSnapshotGas("TgStable", "Mint tgDOLA with stake");
        tgDOLA.mint(usr1, amountIn, true);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(stable.balanceOf(usr1), 0);
        assertEq(tgDOLA.balanceOf(usr1), amountIn);
        assertEq(tgDOLA.socFeePending(), 0);
    }

    function test_mint_without_stake() external {
        address receiver = usr3;
        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(tgDOLA), MAX_UINT);
        vm.startSnapshotGas("TgStable", "Mint tgDOLA without stake");
        tgDOLA.mint(receiver, amountIn, false);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(stable.balanceOf(usr2), 0, "User spent all its balance");
        assertEq(stable.balanceOf(address(tgDOLA)), amountIn);

        assertEq(tgDOLA.balanceOf(receiver), 9_800 ether);
        assertEq(tgDOLA.socFeePending(), 200 ether);

        vm.prank(usr3);
        tgDOLA.burn(usr3, 9_800 ether);

        assertEq(stable.balanceOf(usr3), 9_800 ether);
        assertEq(tgDOLA.balanceOf(usr3), 0);
        assertEq(tgDOLA.socFeePending(), 200 ether);

        deal(address(stable), usr2, 1);
        vm.prank(usr2);
        tgDOLA.mint(usr2, 1, true);

        assertEq(stable.balanceOf(usr2), 0, "User spent all its balance");
        assertEq(stable.balanceOf(address(tgDOLA)), 0);

        assertEq(tgDOLA.balanceOf(usr2), 200000000000000000001);
        assertEq(tgDOLA.socFeePending(), 0);
    }

    function test_burn_tgDOLA() external {
        vm.startPrank(usr1);
        deal(address(stable), usr1, amountIn);
        stable.approve(address(tgDOLA), MAX_UINT);
        tgDOLA.mint(usr1, amountIn, true);
        vm.stopPrank();

        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(tgDOLA), MAX_UINT);
        tgDOLA.mint(usr2, amountIn, true);
        vm.stopPrank();

        uint256 tgDolaUsr1Bal = tgDOLA.balanceOf(usr1);
        verifyLostERC20(tgDOLA, usr1, tgDolaUsr1Bal, "All tgDOLA of the user needs is burnt");
        verifyReceiveERC20(stable, usr1, tgDolaUsr1Bal, "Balance in tgDOLA is converted to DOLA");

        vm.startPrank(usr1);
        vm.startSnapshotGas("TgStable", "Burn tgDOLA");
        tgDOLA.burn(usr1, tgDolaUsr1Bal);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertERC20Tracking();
        assertEq(tgDOLA.balanceOf(usr1), 0, "No more tgDOLA when all balance has been burnt");
        assertEq(stable.balanceOf(usr1), tgDolaUsr1Bal);

        vm.startPrank(usr2);
        tgDOLA.burn(usr2, 100 ether);
        tgDOLA.burn(usr2, 100 ether);
        tgDOLA.burn(usr2, tgDOLA.balanceOf(usr2));
        vm.stopPrank();

        assertEq(tgDOLA.totalSupply(), 1 ether, "Leftover on the totalSupply");
        assertApproxEqAbs(saving.balanceOf(address(tgDOLA)), donationShare, 1, "No more share on tgDOLA because everything has been withdrawn from the saving");

        assertEq(tgDOLA.balanceOf(usr2), 0, "Balance in tgDOLA of usr2");
        assertEq(stable.balanceOf(usr2), amountIn, "User 2 retrieve the exact amount 1:1 of stable");
    }

    function test_claimRewards_tgDOLA() external {
        vm.startPrank(usr1);
        deal(address(stable), usr1, amountIn);
        stable.approve(address(tgDOLA), MAX_UINT);

        assertEq(0, saving.balanceOf(address(tgDOLA)), "No sharesOUAAh");
        tgDOLA.mint(usr1, amountIn, false);

        uint256 socFeePending = tgDOLA.socFeePending();

        assertEq(200 ether, socFeePending);

        assertEq(0, saving.balanceOf(address(tgDOLA)), "No shares on tgDOLA as nothing is staked");

        uint256 pps = saving.previewDeposit(1e18);

        skip(1 weeks);

        assertLt(saving.previewDeposit(1e18), pps);

        vm.stopPrank();

        verifyReceiveERC20(stable, feeTreasury, socFeePending, "Fee Treasury must receive the socFeePending");

        vm.prank(owner);
        tgDOLA.claimRewards();

        assertEq(stable.balanceOf(address(tgDOLA)), 0, "No stable in pending after a claim Rewards");
        assertApproxEqAbs(amountIn - socFeePending, saving.maxWithdraw(address(tgDOLA)), 1, "User must be able to withdraw its crvUSD");
        assertEq(0, tgDOLA.socFeePending(), "Soc fee pending is now 0");

        assertERC20Tracking();

        vm.startPrank(usr1);
        deal(address(stable), usr1, amountIn);
        tgDOLA.mint(usr1, amountIn, true);

        assertEq(0, tgDOLA.socFeePending(), "Soc fee pending is still 0 because mint is done with isStaked = true");
    }
}
