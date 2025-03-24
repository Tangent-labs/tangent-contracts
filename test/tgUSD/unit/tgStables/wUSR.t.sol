// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;
// import "../../contexts/ConvexCurveContext.sol";

// contract wUSR is ConvexCurveContext {
//     IERC20 stable = AddrClassicERC20.TOKEN_USR;
//     IERC4626 saving = AddrERC4626.WST_USR;
//     IERC20 stUSR = AddrClassicERC20.TOKEN_STUSR;

//     uint256 amountIn = 10_000 ether;
//     function test_mint_with_stable() external {
//         vm.startPrank(usr1);
//         deal(address(stable), usr1, amountIn);
//         stable.approve(address(wUSR), MAX_UINT);

//         verifyReceiveERC20(wUSR, usr1, amountIn);
//         verifyLostERC20(stable, usr1, amountIn);
//         verifyReceiveERC20(saving, address(wUSR), saving.convertToShares(amountIn));

//         vm.startSnapshotGas("wUSR", "Mint wUSR with USR");
//         wUSR.mint(usr1, amountIn, false);
//         vm.stopSnapshotGas();

//         assertERC20Tracking();
//         vm.stopPrank();
//     }

//     function test_mint_with_saving() external {
//         vm.startPrank(usr1);
//         deal(address(saving), usr1, amountIn);
//         saving.approve(address(wUSR), MAX_UINT);

//         verifyReceiveERC20(wUSR, usr1, saving.convertToAssets(amountIn));
//         verifyLostERC20(saving, usr1, amountIn);
//         verifyReceiveERC20(saving, address(wUSR), amountIn);

//         vm.startSnapshotGas("wUSR", "Mint wUSR with wstUSR");
//         wUSR.mint(usr1, amountIn, true);
//         vm.stopSnapshotGas();

//         assertERC20Tracking();
//         vm.stopPrank();
//     }

//     function test_burn_and_receive_stable() external {
//         vm.startPrank(usr1);
//         deal(address(stable), usr1, amountIn);
//         stable.approve(address(wUSR), MAX_UINT);
//         wUSR.mint(usr1, amountIn, false);

//         verifyReceiveERC20(stable, usr1, amountIn);
//         verifyLostERC20(wUSR, usr1, amountIn);
//         verifyLostERC20(saving, address(wUSR), saving.previewWithdraw(amountIn));

//         vm.startSnapshotGas("wUSR", "Burn wUSR and receives USR");
//         wUSR.burn(usr1, amountIn, false);
//         vm.stopSnapshotGas();

//         assertERC20Tracking();
//         vm.stopPrank();
//     }

//     function test_burn_and_receive_saving() external {
//         vm.startPrank(usr1);
//         deal(address(stable), usr1, amountIn);
//         stable.approve(address(wUSR), MAX_UINT);
//         wUSR.mint(usr1, amountIn, false);

//         verifyReceiveERC20(saving, usr1, saving.previewWithdraw(amountIn));
//         verifyLostERC20(wUSR, usr1, amountIn);
//         verifyLostERC20(saving, address(wUSR), saving.previewWithdraw(amountIn));

//         vm.startSnapshotGas("wUSR", "Burn wUSR and receives wstUSR");
//         wUSR.burn(usr1, amountIn, true);
//         vm.stopSnapshotGas();

//         assertERC20Tracking();
//         vm.stopPrank();
//     }

//     function test_claimRewards_wUSR() external {
//         uint256 amountToDistribute = 3_000_000 ether;
//         vm.startPrank(usr1);
//         deal(address(stable), usr1, amountToDistribute);
//         stable.approve(address(wUSR), MAX_UINT);
//         wUSR.mint(usr1, amountIn, false);

//         uint256 pps = saving.previewDeposit(1e18);

//         // Simulate a reward distribution ( increase the index )
//         stable.transfer(address(stUSR), amountToDistribute - amountIn);

//         skip(1 weeks);

//         assertLt(saving.previewDeposit(1e18), pps);

//         vm.stopPrank();

//         verifyReceiveERC20(
//             stable,
//             feeTreasury,
//             saving.maxWithdraw(address(wUSR)) - wUSR.totalSupply(),
//             "Fee Treasury must receive the delta between total withdrawable from saving and totalSupply of tgStable"
//         );

//         vm.prank(owner);
//         wUSR.claimRewards();

//         assertGe(saving.maxWithdraw(address(wUSR)), amountIn, "User must be able to withdraw its crvUSD");

//         vm.startPrank(usr1);
//         wUSR.burn(usr1, amountIn, false);

//         assertERC20Tracking();
//     }
// }
