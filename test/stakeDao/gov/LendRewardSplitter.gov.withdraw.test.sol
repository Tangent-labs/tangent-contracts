// import {Test, console} from "forge-std/Test.sol";
// import {DeployContext} from "../DeployContext.sol";
// import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
// import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20} from "../../src/libs/Resources.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {ILlamaVault} from "../../src/interfaces/externals/ILlamaVault.sol";
// import {ILendRewardSplitter} from "../../src/interfaces/internals/ILendRewardSplitter.sol";
// import {ISplitterToken} from "../../src/interfaces/internals/ISplitterToken.sol";

// contract LendRewardSplitterGovWithdrawTest is Test {
//     LendRewardSplitter splitter;
//     DeployContext testCommon;

//     function setUp() public {
//         testCommon = new DeployContext();
//         testCommon.fork();
//         testCommon.setUpSplitter();
//         splitter = testCommon.splitter();
//     }

//     function test_withdraw_FullLendAssetFromgUsd() external {
//         // Setup.
//         address tokenIn = address(AddrClassicERC20.TOKEN_CRVUSD);
//         address user = testCommon.getUser(1, tokenIn);

//         ISplitterToken gUSD = splitter.gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);

//         // Check the initial.
//         assertEq(testCommon.gUSDImplem().balanceOf(user), 0);
//         assertEq(gUSD.totalSupply(), 0);
//         uint256 balancecrvUSDBeforeDeposit = testCommon.crvUSD().balanceOf(user);

//         // Deposit
//         uint256 depositAmount = 100 ether;
//         testCommon.deposit(depositAmount, false, true, tokenIn);

//         // Check deposit.
//         assertApproxEqAbs(gUSD.totalSupply(), depositAmount, 1 wei, "govDepositTotal before withdraw");
//         uint256 balanceDeposited = testCommon.gUSDImplem().balanceOf(user);
//         assertApproxEqAbs(balanceDeposited, depositAmount, 1 wei, "balancegUsdBefore before withdraw");
//         assertEq(testCommon.crvUSD().balanceOf(user), balancecrvUSDBeforeDeposit - depositAmount);

//         // Advance in time.
//         skip(100 days);

//         // Withdraw.
//         testCommon.widthraw(balanceDeposited, false, ILendRewardSplitter.SDT_TOKEN_TYPE.LendAsset);

//         // Chek widthraw IN.
//         assertApproxEqAbs(balancecrvUSDBeforeDeposit, testCommon.crvUSD().balanceOf(user), 2 wei, "balance crvUSD  After withdraw");
//         assertGt(splitter.sdtGaugePerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).balanceOf(address(gUSD)), 0, "Share stay on Stake");

//         // Chek widthraw OUT.
//         uint256 balanceWithdrawn = testCommon.gUSDImplem().balanceOf(user);
//         assertEq(balanceWithdrawn, 0, "balancegUsdAfter After withdraw");
//         assertEq(gUSD.totalSupply(), 0, "govDepositTotal After withdraw");

//         vm.stopPrank();
//     }

//     function test_withdraw_FullLendCurveAssetFromgUsd() external {
//         // Setup.
//         address tokenIn = address(AddrClassicERC20.TOKEN_CRVUSD);
//         address user = testCommon.getUser(1, tokenIn);
//         ISplitterToken gUSD = splitter.gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);

//         // Check the initial.
//         assertEq(gUSD.balanceOf(user), 0);
//         assertEq(gUSD.totalSupply(), 0);
//         uint256 balancecrvUSDBeforeDeposit = testCommon.crvUSD().balanceOf(user);

//         // Deposit
//         uint256 depositAmount = 100 ether;
//         testCommon.deposit(depositAmount, false, true, tokenIn);

//         // Check deposit.
//         assertApproxEqAbs(gUSD.totalSupply(), depositAmount, 1 wei, "govDepositTotal before withdraw");
//         uint256 balanceDeposited = gUSD.balanceOf(user);
//         assertApproxEqAbs(balanceDeposited, depositAmount, 1 wei, "balancegUsdBefore before withdraw");
//         assertEq(testCommon.crvUSD().balanceOf(user), balancecrvUSDBeforeDeposit - depositAmount);

//         // Advance in time.
//         skip(100 days);

//         // Withdraw.
//         testCommon.widthraw(balanceDeposited, false, ILendRewardSplitter.SDT_TOKEN_TYPE.LlamalendVaultAsset);

//         // Chek widthraw IN.
//         assertApproxEqAbs(
//             testCommon.curveLendVault().balanceOf(user),
//             testCommon.curveLendVault().convertToShares(balanceDeposited),
//             1 wei,
//             " balance curveLendValut after"
//         );
//         //TODO Replace
//         assertGt(AddrSdtGauges.CRVUSD_CRV.balanceOf(address(gUSD)), 0, "Share stay on Stake");
//         // Chek widthraw OUT.
//         assertApproxEqAbs(balancecrvUSDBeforeDeposit - depositAmount, testCommon.crvUSD().balanceOf(user), 2 wei, "balance crvUSD  After withdraw");
//         uint256 balanceWithdrawn = gUSD.balanceOf(user);
//         assertEq(balanceWithdrawn, 0, "balancegUsdAfter After withdraw");
//         assertEq(gUSD.totalSupply(), 0, "govDepositTotal After withdraw");

//         vm.stopPrank();
//     }

//     function test_withdraw_FullLendStakeDaoAssetFromgUsd() external {
//         // Setup.
//         address tokenIn = address(AddrClassicERC20.TOKEN_CRVUSD);
//         address user = testCommon.getUser(1, tokenIn);
//         ISplitterToken gUSD = splitter.gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV);

//         // Check the initial.
//         assertEq(gUSD.balanceOf(user), 0);
//         assertEq(gUSD.totalSupply(), 0);
//         assertEq(testCommon.stakeDaoVault().balanceOf(user), 0);
//         uint256 balancecrvUSDBeforeDeposit = testCommon.crvUSD().balanceOf(user);

//         // Deposit
//         uint256 depositAmount = 100 ether;
//         testCommon.deposit(depositAmount, false, true, tokenIn);

//         // Check deposit.
//         assertApproxEqAbs(gUSD.totalSupply(), depositAmount, 1 wei, "govDepositTotal before withdraw");
//         uint256 balanceDeposited = testCommon.gUSDImplem().balanceOf(user);
//         assertApproxEqAbs(balanceDeposited, depositAmount, 1 wei, "balancegUsdBefore before withdraw");
//         assertEq(testCommon.crvUSD().balanceOf(user), balancecrvUSDBeforeDeposit - depositAmount);

//         // Advance in time.
//         skip(100 days);

//         // Withdraw.
//         testCommon.widthraw(balanceDeposited, false, ILendRewardSplitter.SDT_TOKEN_TYPE.SdtGaugeAsset);

//         // Chek widthraw IN.
//         assertApproxEqAbs(
//             IERC20(testCommon.stakeDaoVault().liquidityGauge()).balanceOf(user),
//             testCommon.curveLendVault().convertToShares(balanceDeposited),
//             1 wei,
//             " balance stakeDaoVault after"
//         );
//         //TODO
//         // assertGt(splitter.stakeDaoVaultShareOwned(AddrSdtVaults.CRVUSD_CRV), 0, "Share stay on Stake");

//         // Chek widthraw OUT.
//         assertApproxEqAbs(balancecrvUSDBeforeDeposit - depositAmount, testCommon.crvUSD().balanceOf(user), 2 wei, "balance crvUSD  After withdraw");
//         uint256 balanceWithdrawn = testCommon.gUSDImplem().balanceOf(user);
//         assertEq(balanceWithdrawn, 0, "balancegUsdAfter After withdraw");
//         assertEq(splitter.gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), 0, "govDepositTotal After withdraw");

//         vm.stopPrank();
//     }

//     function test_withdraw_curveLendVaultSolo() external {
//         ILlamaVault curveLendVault = testCommon.curveLendVault();
//         IERC20 crvUSD = testCommon.crvUSD();
//         uint256 depositAmount = 100 ether;
//         address tokenIn = address(AddrClassicERC20.TOKEN_CRVUSD);
//         address user = testCommon.getUser(1, tokenIn);
//         vm.startPrank(user);
//         crvUSD.approve(address(AddrLlamaLendVaults.CRVUSD_CRV), testCommon.MAX_UINT());
//         assertApproxEqAbs(crvUSD.balanceOf(user), 1000 ether, 1 wei);
//         uint256 share = curveLendVault.deposit(depositAmount);
//         assertApproxEqAbs(crvUSD.balanceOf(user), 900 ether, 1 wei);
//         uint256 assets = curveLendVault.redeem(share);
//         assertApproxEqAbs(depositAmount, assets, 1 wei);
//         assertApproxEqAbs(crvUSD.balanceOf(user), 1000 ether, 1 wei);
//         vm.stopPrank();
//     }
// }
