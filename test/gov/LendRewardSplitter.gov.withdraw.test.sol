import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {ICurveLendVault} from "../../src/interfaces/ICurveLendVault.sol";

contract LendRewardSplitterGovWithdrawTest is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon;

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        splitter = testCommon.setUpSplitter();
    }

    function test_withdraw_FullLendAssetFromgUsd() external {
        // Setup.
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn);

        // Check the initial.
        assertEq(testCommon.gUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().govDepositTotal(), 0);
        uint256 balancecrvUSDBeforeDeposit = testCommon.crvUSD().balanceOf(user);

        // Deposit
        uint256 depositAmount = 100 ether;
        testCommon.deposit(depositAmount, false, true, tokenIn);

        // Check deposit.
        assertApproxEqAbs(
            testCommon.splitter().govDepositTotal(),
            depositAmount,
            1 wei,
            "govDepositTotal before withdraw"
        );
        uint256 balanceDeposited = testCommon.gUSD().balanceOf(user);
        assertApproxEqAbs(balanceDeposited, depositAmount, 1 wei, "balancegUsdBefore before withdraw");
        assertEq(testCommon.crvUSD().balanceOf(user), balancecrvUSDBeforeDeposit - depositAmount);

        // Advance in time.
        skip(100 days);

        // Withdraw.
        testCommon.widthraw(balanceDeposited, false, LendRewardSplitter.TOKEN_TYPE.LendAsset);

        // Chek widthraw IN.
        assertApproxEqAbs(
            balancecrvUSDBeforeDeposit,
            testCommon.crvUSD().balanceOf(user),
            2 wei,
            "balance crvUSD  After withdraw"
        );
        assertGt(splitter.stakeDaoVaultShareOwned(), 0, "Share stay on Stake");

        // Chek widthraw OUT.
        uint256 balanceWithdrawn = testCommon.gUSD().balanceOf(user);
        assertEq(balanceWithdrawn, 0, "balancegUsdAfter After withdraw");
        assertEq(testCommon.splitter().govDepositTotal(), 0, "govDepositTotal After withdraw");

        vm.stopPrank();
    }

    function test_withdraw_FullLendCurveAssetFromgUsd() external {
        // Setup.
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn);

        // Check the initial.
        assertEq(testCommon.gUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().govDepositTotal(), 0);
        uint256 balancecrvUSDBeforeDeposit = testCommon.crvUSD().balanceOf(user);

        // Deposit
        uint256 depositAmount = 100 ether;
        testCommon.deposit(depositAmount, false, true, tokenIn);

        // Check deposit.
        assertApproxEqAbs(
            testCommon.splitter().govDepositTotal(),
            depositAmount,
            1 wei,
            "govDepositTotal before withdraw"
        );
        uint256 balanceDeposited = testCommon.gUSD().balanceOf(user);
        assertApproxEqAbs(balanceDeposited, depositAmount, 1 wei, "balancegUsdBefore before withdraw");
        assertEq(testCommon.crvUSD().balanceOf(user), balancecrvUSDBeforeDeposit - depositAmount);

        // Advance in time.
        console.log("pps before", testCommon.curvelendVault().pricePerShare());
        skip(100 days);
        console.log("pps after", testCommon.curvelendVault().pricePerShare());

        // Withdraw.
        testCommon.widthraw(balanceDeposited, false, LendRewardSplitter.TOKEN_TYPE.LendCurveAsset);

        // Chek widthraw IN.
        assertApproxEqAbs(
            testCommon.curvelendVault().balanceOf(user),
            testCommon.curvelendVault().convertToShares(balanceDeposited),
            1 wei,
            " balance curveLendValut after"
        );
        assertGt(splitter.stakeDaoVaultShareOwned(), 0, "Share stay on Stake");
        // Chek widthraw OUT.
        assertApproxEqAbs(
            balancecrvUSDBeforeDeposit - depositAmount,
            testCommon.crvUSD().balanceOf(user),
            2 wei,
            "balance crvUSD  After withdraw"
        );
        uint256 balanceWithdrawn = testCommon.gUSD().balanceOf(user);
        assertEq(balanceWithdrawn, 0, "balancegUsdAfter After withdraw");
        assertEq(testCommon.splitter().govDepositTotal(), 0, "govDepositTotal After withdraw");

        vm.stopPrank();
    }

    function test_withdraw_FullLendStakeDaoAssetFromgUsd() external {
        // Setup.
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn);

        // Check the initial.
        assertEq(testCommon.gUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().govDepositTotal(), 0);
        assertEq(testCommon.stakeDaoLendVault().balanceOf(user), 0);
        uint256 balancecrvUSDBeforeDeposit = testCommon.crvUSD().balanceOf(user);

        // Deposit
        uint256 depositAmount = 100 ether;
        testCommon.deposit(depositAmount, false, true, tokenIn);

        // Check deposit.
        assertApproxEqAbs(
            testCommon.splitter().govDepositTotal(),
            depositAmount,
            1 wei,
            "govDepositTotal before withdraw"
        );
        uint256 balanceDeposited = testCommon.gUSD().balanceOf(user);
        assertApproxEqAbs(balanceDeposited, depositAmount, 1 wei, "balancegUsdBefore before withdraw");
        assertEq(testCommon.crvUSD().balanceOf(user), balancecrvUSDBeforeDeposit - depositAmount);

        // Advance in time.
        console.log("pps before", testCommon.curvelendVault().pricePerShare());
        skip(100 days);
        console.log("pps after", testCommon.curvelendVault().pricePerShare());

        // Withdraw.
        testCommon.widthraw(balanceDeposited, false, LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset);

        // Chek widthraw IN.
        assertApproxEqAbs(
            IERC20(testCommon.stakeDaoLendVault().liquidityGauge()).balanceOf(user),
            testCommon.curvelendVault().convertToShares(balanceDeposited),
            1 wei,
            " balance stakeDaoLendVault after"
        );
        assertGt(splitter.stakeDaoVaultShareOwned(), 0, "Share stay on Stake");

        // Chek widthraw OUT.
        assertApproxEqAbs(
            balancecrvUSDBeforeDeposit - depositAmount,
            testCommon.crvUSD().balanceOf(user),
            2 wei,
            "balance crvUSD  After withdraw"
        );
        uint256 balanceWithdrawn = testCommon.gUSD().balanceOf(user);
        assertEq(balanceWithdrawn, 0, "balancegUsdAfter After withdraw");
        assertEq(testCommon.splitter().govDepositTotal(), 0, "govDepositTotal After withdraw");

        vm.stopPrank();
    }

    function test_withdraw_curveLendVaultSolo() external {
        ICurveLendVault curvelendVault = testCommon.curvelendVault();
        IERC20 crvUSD = testCommon.crvUSD();
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn);
        vm.startPrank(user);
        crvUSD.approve(testCommon.CURVE_CRV_VAULT(), testCommon.MAX_UINT());
        assertApproxEqAbs(crvUSD.balanceOf(user), 1000 ether, 1 wei);
        uint256 share = curvelendVault.deposit(depositAmount);
        assertApproxEqAbs(crvUSD.balanceOf(user), 900 ether, 1 wei);
        uint256 assets = curvelendVault.redeem(share);
        assertApproxEqAbs(depositAmount, assets, 1 wei);
        assertApproxEqAbs(crvUSD.balanceOf(user), 1000 ether, 1 wei);
        vm.stopPrank();
    }
}
