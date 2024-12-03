// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

contract TgCrvUSD is ConvexCurveContext {
    IERC20 stable = AddrClassicERC20.TOKEN_CRVUSD;
    IERC4626 saving = AddrERC4626.S_CRVUSD;

    function test_mint() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(tgCrvUSD), MAX_UINT);

        vm.startSnapshotGas("TgStable", "Mint tgCRVUSD");
        tgCrvUSD.mint(usr1, amountIn, true);
        vm.stopSnapshotGas();

        vm.stopPrank();

        assertEq(stable.balanceOf(usr1), 0);
        assertEq(tgCrvUSD.balanceOf(usr1), amountIn);

        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(tgCrvUSD), MAX_UINT);
        tgCrvUSD.mint(usr2, amountIn, true);
        vm.stopPrank();

        assertEq(stable.balanceOf(usr2), 0);
        assertEq(tgCrvUSD.balanceOf(usr2), amountIn);
    }

    function test_burn() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(tgCrvUSD), MAX_UINT);
        tgCrvUSD.mint(usr1, amountIn, true);
        vm.stopPrank();

        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(tgCrvUSD), MAX_UINT);
        tgCrvUSD.mint(usr2, amountIn, true);
        vm.stopPrank();

        vm.startPrank(usr1);
        vm.startSnapshotGas("TgStable", "Burn tgCRVUSD");
        tgCrvUSD.burn(usr1, amountIn);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(tgCrvUSD.balanceOf(usr1), 0);
        assertEq(stable.balanceOf(usr1), amountIn);

        vm.startPrank(usr2);
        tgCrvUSD.burn(usr2, amountIn);
        vm.stopPrank();

        assertEq(tgCrvUSD.balanceOf(usr2), 0);
        assertEq(stable.balanceOf(usr2), amountIn);
    }

    function test_claimRewards() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(tgCrvUSD), MAX_UINT);
        tgCrvUSD.mint(usr1, amountIn, true);

        uint256 pps = saving.previewDeposit(1e18);

        deal(address(stable), address(AddrERC4626.REWARD_HANDLER_SCRVUSD), 100_000 ether);
        AddrERC4626.REWARD_HANDLER_SCRVUSD.process_rewards(false);

        skip(1 weeks);

        assertLt(saving.previewDeposit(1e18), pps);

        vm.stopPrank();

        verifyReceiveERC20(
            stable,
            feeTreasury,
            saving.maxWithdraw(address(tgCrvUSD)) - tgCrvUSD.totalSupply(),
            "Fee Treasury must receive the delta between total withdrawable from saving and totalSupply of tgStable"
        );

        vm.prank(owner);
        tgCrvUSD.claimRewards();

        assertGe(saving.maxWithdraw(address(tgCrvUSD)), amountIn, "User must be able to withdraw its crvUSD");

        vm.startPrank(usr1);
        tgCrvUSD.burn(usr1, amountIn);

        assertERC20Tracking();
    }
}
