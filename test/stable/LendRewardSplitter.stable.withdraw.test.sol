import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {Addresses} from "../../src/libs/Addresses.sol";

contract LendRewardSplitterStableWithdrawTest is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon;

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        splitter = testCommon.setUpSplitter();
    }

    function test_withdraw_FullLendAssetFromscvUSD() external {
        // Setup.
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn, depositAmount);

        // Check the initial.
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        assertEq(testCommon.crvUSD().balanceOf(user), depositAmount);

        // Deposit
        testCommon.deposit(depositAmount, true, true, tokenIn);
        uint256 expectedDeposit = testCommon.curveLendVault().convertToShares(depositAmount);

        // Check deposit.
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT),
            expectedDeposit,
            1 wei,
            "stableDepositTotal before withdraw"
        );
        uint256 balanceDeposited = testCommon.scvUSD().balanceOf(user);
        assertApproxEqAbs(balanceDeposited, expectedDeposit, 1 wei, "balancescvUSDBefore before withdraw");
        assertEq(testCommon.crvUSD().balanceOf(user), 0, "balance crvUSD  before withdraw");

        // Advance in time.
        skip(100 days);

        // Withdraw.
        testCommon.widthraw(balanceDeposited, true, LendRewardSplitter.TOKEN_TYPE.LendAsset);

        // Chek widthraw IN.
        uint256 balancescvUsdAfter = testCommon.scvUSD().balanceOf(user);
        assertEq(balancescvUsdAfter, 0, "balance scvUsd  After withdraw");
        assertEq(
            testCommon.curveLendVault().convertToAssets(balanceDeposited),
            testCommon.crvUSD().balanceOf(user),
            "balance crvUSD  After withdraw"
        );

        // Chek widthraw OUT.
        uint256 balanceWithdrawn = testCommon.scvUSD().balanceOf(user);
        assertEq(balanceWithdrawn, 0, "balancescvUSDAfter After withdraw");
        assertEq(
            testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT),
            0,
            "stableDepositTotal After withdraw"
        );

        vm.stopPrank();
    }

    function test_withdraw_HalfLendAssetFromscvUSD() external {
        // Setup.
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn, depositAmount);

        // Check the initial.
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        assertEq(testCommon.crvUSD().balanceOf(user), depositAmount);

        // Deposit
        testCommon.deposit(depositAmount, true, true, tokenIn);
        uint256 expectedDeposit = testCommon.curveLendVault().convertToShares(depositAmount);

        // Check deposit.
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT),
            expectedDeposit,
            1 wei,
            "stableDepositTotal before withdraw"
        );
        uint256 balanceDeposited = testCommon.scvUSD().balanceOf(user);
        assertApproxEqAbs(balanceDeposited, expectedDeposit, 1 wei, "balancescvUSDBefore before withdraw");
        assertEq(testCommon.crvUSD().balanceOf(user), 0, "balance crvUSD  before withdraw");

        // Advance in time.
        skip(100 days);

        // Withdraw.
        testCommon.widthraw(balanceDeposited / 2, true, LendRewardSplitter.TOKEN_TYPE.LendAsset);

        // Chek widthraw IN.
        uint256 balancescvUsdAfter = testCommon.scvUSD().balanceOf(user);
        assertApproxEqAbs(balancescvUsdAfter, balanceDeposited / 2, 1 wei, "balance scvUsd  After withdraw");
        assertApproxEqAbs(
            testCommon.curveLendVault().convertToAssets(balanceDeposited / 2),
            testCommon.crvUSD().balanceOf(user),
            1 wei,
            "balance crvUSD  After withdraw"
        );

        // Chek widthraw OUT.
        uint256 balanceWithdrawn = testCommon.scvUSD().balanceOf(user);
        assertApproxEqAbs(balanceWithdrawn, balanceDeposited / 2, 1 wei, "balancescvUSDAfter After withdraw");
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT),
            balanceDeposited / 2,
            1 wei,
            "stableDepositTotal After withdraw"
        );

        vm.stopPrank();
    }

    function test_withdraw_FullLendCurveAssetFromscvUSD() external {
        // Setup.
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn, depositAmount);

        // Check the initial.
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        assertEq(testCommon.crvUSD().balanceOf(user), depositAmount);

        // Deposit
        testCommon.deposit(depositAmount, true, true, tokenIn);
        uint256 expectedDeposit = testCommon.curveLendVault().convertToShares(depositAmount);

        // Check deposit.
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT),
            expectedDeposit,
            1 wei,
            "stableDepositTotal before withdraw"
        );
        uint256 balanceDeposited = testCommon.scvUSD().balanceOf(user);
        assertApproxEqAbs(balanceDeposited, expectedDeposit, 1 wei, "balancescvUSDBefore before withdraw");
        assertEq(testCommon.crvUSD().balanceOf(user), 0, "balance crvUSD  before withdraw");

        // Advance in time.
        skip(100 days);

        // Withdraw.
        testCommon.widthraw(balanceDeposited, true, LendRewardSplitter.TOKEN_TYPE.LendCurveAsset);

        // Chek widthraw IN.
        uint256 balancescvUsdAfter = testCommon.scvUSD().balanceOf(user);
        assertEq(balancescvUsdAfter, 0, "balance scvUsd  After withdraw");
        assertEq(balanceDeposited, testCommon.curveLendVault().balanceOf(user), "balance crvUSD  After withdraw");

        // Chek widthraw OUT.
        uint256 balanceWithdrawn = testCommon.scvUSD().balanceOf(user);
        assertEq(balanceWithdrawn, 0, "balancescvUSDAfter After withdraw");
        assertEq(
            testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT),
            0,
            "stableDepositTotal After withdraw"
        );

        vm.stopPrank();
    }

    function test_withdraw_HalfLendCurveAssetFromscvUSD() external {
        // Setup.
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn, depositAmount);

        // Check the initial.
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        assertEq(testCommon.crvUSD().balanceOf(user), depositAmount);

        // Deposit
        testCommon.deposit(depositAmount, true, true, tokenIn);
        uint256 expectedDeposit = testCommon.curveLendVault().convertToShares(depositAmount);

        // Check deposit.
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT),
            expectedDeposit,
            1 wei,
            "stableDepositTotal before withdraw"
        );
        uint256 balanceDeposited = testCommon.scvUSD().balanceOf(user);
        assertApproxEqAbs(balanceDeposited, expectedDeposit, 1 wei, "balancescvUSDBefore before withdraw");
        assertEq(testCommon.crvUSD().balanceOf(user), 0, "balance crvUSD  before withdraw");

        // Advance in time.
        skip(100 days);

        // Withdraw.
        testCommon.widthraw(balanceDeposited / 2, true, LendRewardSplitter.TOKEN_TYPE.LendCurveAsset);

        // Chek widthraw IN.
        uint256 balancescvUsdAfter = testCommon.scvUSD().balanceOf(user);
        assertApproxEqAbs(balancescvUsdAfter, balanceDeposited / 2, 1 wei, "balance scvUsd  After withdraw");
        assertApproxEqAbs(
            balanceDeposited / 2,
            testCommon.curveLendVault().balanceOf(user),
            1 wei,
            "balance crvUSD  After withdraw"
        );

        // Chek widthraw OUT.
        uint256 balanceWithdrawn = testCommon.scvUSD().balanceOf(user);
        assertApproxEqAbs(balanceWithdrawn, balanceDeposited / 2, 1 wei, "balancescvUSDAfter After withdraw");
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT),
            balanceDeposited / 2,
            1 wei,
            "stableDepositTotal After withdraw"
        );

        vm.stopPrank();
    }

    function test_withdraw_FullLendStakeDaoAssetFromscvUSD() external {
        // Setup.
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn, depositAmount);
        IERC20 stakeLiquidityGauge = IERC20(testCommon.stakeDaoVault().liquidityGauge());

        // Check the initial.
        assertEq(stakeLiquidityGauge.balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        assertEq(testCommon.crvUSD().balanceOf(user), depositAmount);

        // Deposit
        testCommon.deposit(depositAmount, true, true, tokenIn);
        uint256 expectedDeposit = testCommon.curveLendVault().convertToShares(depositAmount);

        // Check deposit.
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT),
            expectedDeposit,
            1 wei,
            "stableDepositTotal before withdraw"
        );
        uint256 balanceDeposited = testCommon.scvUSD().balanceOf(user);
        assertApproxEqAbs(balanceDeposited, expectedDeposit, 1 wei, "balancescvUSDBefore before withdraw");
        assertEq(testCommon.crvUSD().balanceOf(user), 0, "balance crvUSD  before withdraw");

        // Advance in time.
        skip(100 days);

        // Withdraw.
        testCommon.widthraw(balanceDeposited, true, LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset);

        // Chek widthraw IN.
        uint256 balancescvUsdAfter = testCommon.scvUSD().balanceOf(user);
        assertEq(balancescvUsdAfter, 0, "balance scvUsd  After withdraw");
        assertEq(balanceDeposited, stakeLiquidityGauge.balanceOf(user), "balance stakeLiquidityGauge  After withdraw");

        // Chek widthraw OUT.
        uint256 balanceWithdrawn = testCommon.scvUSD().balanceOf(user);
        assertEq(balanceWithdrawn, 0, "balancescvUSDAfter After withdraw");
        assertEq(
            testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT),
            0,
            "stableDepositTotal After withdraw"
        );

        vm.stopPrank();
    }

    function test_withdraw_HalfLendStakeDaoAssetFromscvUSD() external {
        // Setup.
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn, depositAmount);
        IERC20 stakeLiquidityGauge = IERC20(testCommon.stakeDaoVault().liquidityGauge());

        // Check the initial.
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        assertEq(testCommon.crvUSD().balanceOf(user), depositAmount);

        // Deposit
        testCommon.deposit(depositAmount, true, true, tokenIn);
        uint256 expectedDeposit = testCommon.curveLendVault().convertToShares(depositAmount);

        // Check deposit.
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT),
            expectedDeposit,
            1 wei,
            "stableDepositTotal before withdraw"
        );
        uint256 balanceDeposited = testCommon.scvUSD().balanceOf(user);
        assertApproxEqAbs(balanceDeposited, expectedDeposit, 1 wei, "balancescvUSDBefore before withdraw");
        assertEq(testCommon.crvUSD().balanceOf(user), 0, "balance crvUSD  before withdraw");

        // Advance in time.
        skip(100 days);

        // Withdraw.
        testCommon.widthraw(balanceDeposited / 2, true, LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset);

        // Chek widthraw IN.
        uint256 balancescvUsdAfter = testCommon.scvUSD().balanceOf(user);
        assertApproxEqAbs(balancescvUsdAfter, balanceDeposited / 2, 1 wei, "balance scvUsd  After withdraw");
        assertApproxEqAbs(
            balanceDeposited / 2,
            stakeLiquidityGauge.balanceOf(user),
            1 wei,
            "balance crvUSD  After withdraw"
        );

        // Chek widthraw OUT.
        uint256 balanceWithdrawn = testCommon.scvUSD().balanceOf(user);
        assertApproxEqAbs(balanceWithdrawn, balanceDeposited / 2, 1 wei, "balancescvUSDAfter After withdraw");
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT),
            balanceDeposited / 2,
            1 wei,
            "stableDepositTotal After withdraw"
        );

        vm.stopPrank();
    }

    function test_revertWhen_WithdrawLendAssetWithNotEnoughBalance() external {
        uint256 depositAmount = 50 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn);

        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.curveLendVault().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);

        testCommon.deposit(depositAmount, true, true, tokenIn);

        uint256 overWithDraw = testCommon.curveLendVault().convertToShares(100 ether);
        vm.expectRevert();
        testCommon.widthraw(overWithDraw, true, LendRewardSplitter.TOKEN_TYPE.LendAsset);
    }

    function test_revertWhen_WithdrawLendCurveAssetWithNotEnoughBalance() external {
        uint256 depositAmount = 50 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn);

        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.curveLendVault().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);

        testCommon.deposit(depositAmount, true, true, tokenIn);
        uint256 overWithDraw = testCommon.curveLendVault().convertToShares(100 ether);
        vm.expectRevert();
        testCommon.widthraw(overWithDraw, true, LendRewardSplitter.TOKEN_TYPE.LendCurveAsset);
    }

    function test_revertWhen_WithdrawLendStakeAssetWithNotEnoughBalance() external {
        uint256 depositAmount = 10 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn);

        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.curveLendVault().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);

        testCommon.deposit(depositAmount, true, true, tokenIn);
        uint256 overWithDraw = testCommon.curveLendVault().convertToShares(100 ether);

        vm.expectRevert();
        testCommon.widthraw(overWithDraw, true, LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset);
    }
}
