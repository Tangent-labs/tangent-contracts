// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

contract wcrvUSD is ConvexCurveContext {
    IERC20 stable = AddrClassicERC20.TOKEN_CRVUSD;
    IERC4626 saving = AddrERC4626.S_CRVUSD;

    function test_mint() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(wcrvUSD), MAX_UINT);

        vm.startSnapshotGas("TgStable", "Mint wcrvUSD");
        wcrvUSD.mint(usr1, amountIn, false);
        vm.stopSnapshotGas();

        vm.stopPrank();

        assertEq(stable.balanceOf(usr1), 0);
        assertEq(wcrvUSD.balanceOf(usr1), amountIn);

        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(wcrvUSD), MAX_UINT);
        wcrvUSD.mint(usr2, amountIn, false);
        vm.stopPrank();

        assertEq(stable.balanceOf(usr2), 0);
        assertEq(wcrvUSD.balanceOf(usr2), amountIn);
    }

    function test_burn() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(wcrvUSD), MAX_UINT);
        wcrvUSD.mint(usr1, amountIn, false);
        vm.stopPrank();

        vm.startPrank(usr2);
        deal(address(stable), usr2, amountIn);
        stable.approve(address(wcrvUSD), MAX_UINT);
        wcrvUSD.mint(usr2, amountIn, false);
        vm.stopPrank();

        vm.startPrank(usr1);
        vm.startSnapshotGas("TgStable", "Burn wcrvUSD");
        wcrvUSD.burn(usr1, amountIn, false);
        vm.stopSnapshotGas();
        vm.stopPrank();

        assertEq(wcrvUSD.balanceOf(usr1), 0);
        assertEq(stable.balanceOf(usr1), amountIn);

        vm.startPrank(usr2);
        wcrvUSD.burn(usr2, amountIn, false);
        vm.stopPrank();

        assertEq(wcrvUSD.balanceOf(usr2), 0);
        assertEq(stable.balanceOf(usr2), amountIn);
    }

    function test_claimRewards() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        deal(address(stable), usr1, amountIn);
        stable.approve(address(wcrvUSD), MAX_UINT);
        wcrvUSD.mint(usr1, amountIn, false);

        uint256 pps = saving.previewDeposit(1e18);

        deal(address(stable), address(AddrERC4626.REWARD_HANDLER_SCRVUSD), 100_000 ether);
        AddrERC4626.REWARD_HANDLER_SCRVUSD.process_rewards(false);

        skip(1 weeks);

        assertLt(saving.previewDeposit(1e18), pps);

        vm.stopPrank();

        verifyReceiveERC20(
            stable,
            feeTreasury,
            saving.maxWithdraw(address(wcrvUSD)) - wcrvUSD.totalSupply(),
            "Fee Treasury must receive the delta between total withdrawable from saving and totalSupply of tgStable"
        );

        vm.prank(owner);
        wcrvUSD.claimRewards();

        assertGe(saving.maxWithdraw(address(wcrvUSD)), amountIn, "User must be able to withdraw its crvUSD");

        vm.startPrank(usr1);
        wcrvUSD.burn(usr1, amountIn, false);

        assertERC20Tracking();
    }
}
