import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {TokensvcUSD} from "../../src/tokens/TokensvcUSD.sol";
import {TokengUsd} from "../../src/tokens/TokengUsd.sol";
import {IStakeDaoVault} from "../../src/interfaces/IStakeDaoVault.sol";
import {ICurvelendVault} from "../../src/interfaces/ICurvelendVault.sol";

contract LendRewardSplitterStableWithdrawTest is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon;

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        splitter = testCommon.setUpSplitter();
    }

    function test_withdraw_FullLendAssetFromsvcUsd() external {
        // Setup.
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn, depositAmount);

        // Check the initial.
        assertEq(testCommon.svcUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);
        assertEq(testCommon.crvUSD().balanceOf(user), depositAmount);

        // Deposit
        testCommon.deposit(depositAmount, true, true, tokenIn);
        uint256 expectedDeposit = testCommon.curvelendVault().convertToShares(
            depositAmount
        );

        // Check deposit.
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(),
            expectedDeposit,
            1 wei,
            "stableDepositTotal before withdraw"
        );
        uint256 balanceDeposited = testCommon.svcUSD().balanceOf(user);
        assertApproxEqAbs(
            balanceDeposited,
            expectedDeposit,
            1 wei,
            "balancesvcUsdBefore before withdraw"
        );
        assertEq(
            testCommon.crvUSD().balanceOf(user),
            0,
            "balance crvUSD  before withdraw"
        );

        // Advance in time.
        skip(100 days);

        // Withdraw.
        testCommon.widthraw(
            balanceDeposited,
            true,
            LendRewardSplitter.TOKEN_TYPE.LendAsset
        );

        // Chek widthraw IN.
        uint256 balancescvUsdAfter = testCommon.svcUSD().balanceOf(user);
        assertEq(balancescvUsdAfter, 0, "balance scvUsd  After withdraw");
        assertEq(
            testCommon.curvelendVault().convertToAssets(balanceDeposited),
            testCommon.crvUSD().balanceOf(user),
            "balance crvUSD  After withdraw"
        );

        // Chek widthraw OUT.
        uint256 balanceWithdrawn = testCommon.svcUSD().balanceOf(user);
        assertEq(balanceWithdrawn, 0, "balancesvcUsdAfter After withdraw");
        assertEq(
            testCommon.splitter().stableDepositTotal(),
            0,
            "stableDepositTotal After withdraw"
        );

        vm.stopPrank();
    }

    function test_withdraw_HalfLendAssetFromsvcUsd() external {
        // Setup.
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn, depositAmount);

        // Check the initial.
        assertEq(testCommon.svcUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);
        assertEq(testCommon.crvUSD().balanceOf(user), depositAmount);

        // Deposit
        testCommon.deposit(depositAmount, true, true, tokenIn);
        uint256 expectedDeposit = testCommon.curvelendVault().convertToShares(
            depositAmount
        );

        // Check deposit.
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(),
            expectedDeposit,
            1 wei,
            "stableDepositTotal before withdraw"
        );
        uint256 balanceDeposited = testCommon.svcUSD().balanceOf(user);
        assertApproxEqAbs(
            balanceDeposited,
            expectedDeposit,
            1 wei,
            "balancesvcUsdBefore before withdraw"
        );
        assertEq(
            testCommon.crvUSD().balanceOf(user),
            0,
            "balance crvUSD  before withdraw"
        );

        // Advance in time.
        skip(100 days);

        // Withdraw.
        testCommon.widthraw(
            balanceDeposited / 2,
            true,
            LendRewardSplitter.TOKEN_TYPE.LendAsset
        );

        // Chek widthraw IN.
        uint256 balancescvUsdAfter = testCommon.svcUSD().balanceOf(user);
        assertApproxEqAbs(
            balancescvUsdAfter,
            balanceDeposited / 2,
            1 wei,
            "balance scvUsd  After withdraw"
        );
        assertApproxEqAbs(
            testCommon.curvelendVault().convertToAssets(balanceDeposited / 2),
            testCommon.crvUSD().balanceOf(user),
            1 wei,
            "balance crvUSD  After withdraw"
        );

        // Chek widthraw OUT.
        uint256 balanceWithdrawn = testCommon.svcUSD().balanceOf(user);
        assertApproxEqAbs(
            balanceWithdrawn,
            balanceDeposited / 2,
            1 wei,
            "balancesvcUsdAfter After withdraw"
        );
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(),
            balanceDeposited / 2,
            1 wei,
            "stableDepositTotal After withdraw"
        );

        vm.stopPrank();
    }

    function test_withdraw_FullLendCurveAssetFromsvcUsd() external {
        // Setup.
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn, depositAmount);

        // Check the initial.
        assertEq(testCommon.svcUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);
        assertEq(testCommon.crvUSD().balanceOf(user), depositAmount);

        // Deposit
        testCommon.deposit(depositAmount, true, true, tokenIn);
        uint256 expectedDeposit = testCommon.curvelendVault().convertToShares(
            depositAmount
        );

        // Check deposit.
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(),
            expectedDeposit,
            1 wei,
            "stableDepositTotal before withdraw"
        );
        uint256 balanceDeposited = testCommon.svcUSD().balanceOf(user);
        assertApproxEqAbs(
            balanceDeposited,
            expectedDeposit,
            1 wei,
            "balancesvcUsdBefore before withdraw"
        );
        assertEq(
            testCommon.crvUSD().balanceOf(user),
            0,
            "balance crvUSD  before withdraw"
        );

        // Advance in time.
        skip(100 days);

        // Withdraw.
        testCommon.widthraw(
            balanceDeposited,
            true,
            LendRewardSplitter.TOKEN_TYPE.LendCurveAsset
        );

        // Chek widthraw IN.
        uint256 balancescvUsdAfter = testCommon.svcUSD().balanceOf(user);
        assertEq(balancescvUsdAfter, 0, "balance scvUsd  After withdraw");
        assertEq(
            balanceDeposited,
            testCommon.curvelendVault().balanceOf(user),
            "balance crvUSD  After withdraw"
        );

        // Chek widthraw OUT.
        uint256 balanceWithdrawn = testCommon.svcUSD().balanceOf(user);
        assertEq(balanceWithdrawn, 0, "balancesvcUsdAfter After withdraw");
        assertEq(
            testCommon.splitter().stableDepositTotal(),
            0,
            "stableDepositTotal After withdraw"
        );

        vm.stopPrank();
    }

    function test_withdraw_HalfLendCurveAssetFromsvcUsd() external {
        // Setup.
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn, depositAmount);

        // Check the initial.
        assertEq(testCommon.svcUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);
        assertEq(testCommon.crvUSD().balanceOf(user), depositAmount);

        // Deposit
        testCommon.deposit(depositAmount, true, true, tokenIn);
        uint256 expectedDeposit = testCommon.curvelendVault().convertToShares(
            depositAmount
        );

        // Check deposit.
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(),
            expectedDeposit,
            1 wei,
            "stableDepositTotal before withdraw"
        );
        uint256 balanceDeposited = testCommon.svcUSD().balanceOf(user);
        assertApproxEqAbs(
            balanceDeposited,
            expectedDeposit,
            1 wei,
            "balancesvcUsdBefore before withdraw"
        );
        assertEq(
            testCommon.crvUSD().balanceOf(user),
            0,
            "balance crvUSD  before withdraw"
        );

        // Advance in time.
        skip(100 days);

        // Withdraw.
        testCommon.widthraw(
            balanceDeposited / 2,
            true,
            LendRewardSplitter.TOKEN_TYPE.LendCurveAsset
        );

        // Chek widthraw IN.
        uint256 balancescvUsdAfter = testCommon.svcUSD().balanceOf(user);
        assertApproxEqAbs(
            balancescvUsdAfter,
            balanceDeposited / 2,
            1 wei,
            "balance scvUsd  After withdraw"
        );
        assertApproxEqAbs(
            balanceDeposited / 2,
            testCommon.curvelendVault().balanceOf(user),
            1 wei,
            "balance crvUSD  After withdraw"
        );

        // Chek widthraw OUT.
        uint256 balanceWithdrawn = testCommon.svcUSD().balanceOf(user);
        assertApproxEqAbs(
            balanceWithdrawn,
            balanceDeposited / 2,
            1 wei,
            "balancesvcUsdAfter After withdraw"
        );
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(),
            balanceDeposited / 2,
            1 wei,
            "stableDepositTotal After withdraw"
        );

        vm.stopPrank();
    }

    function test_withdraw_FullLendStakeDaoAssetFromsvcUsd() external {
        // Setup.
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn, depositAmount);
        IERC20 stakeLiquidityGauge = IERC20(
            testCommon.stakeDaoLendVault().liquidityGauge()
        );

        // Check the initial.
        assertEq(stakeLiquidityGauge.balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);
        assertEq(testCommon.crvUSD().balanceOf(user), depositAmount);

        // Deposit
        testCommon.deposit(depositAmount, true, true, tokenIn);
        uint256 expectedDeposit = testCommon.curvelendVault().convertToShares(
            depositAmount
        );

        // Check deposit.
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(),
            expectedDeposit,
            1 wei,
            "stableDepositTotal before withdraw"
        );
        uint256 balanceDeposited = testCommon.svcUSD().balanceOf(user);
        assertApproxEqAbs(
            balanceDeposited,
            expectedDeposit,
            1 wei,
            "balancesvcUsdBefore before withdraw"
        );
        assertEq(
            testCommon.crvUSD().balanceOf(user),
            0,
            "balance crvUSD  before withdraw"
        );

        // Advance in time.
        skip(100 days);

        // Withdraw.
        testCommon.widthraw(
            balanceDeposited,
            true,
            LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset
        );

        // Chek widthraw IN.
        uint256 balancescvUsdAfter = testCommon.svcUSD().balanceOf(user);
        assertEq(balancescvUsdAfter, 0, "balance scvUsd  After withdraw");
        assertEq(
            balanceDeposited,
            stakeLiquidityGauge.balanceOf(user),
            "balance stakeLiquidityGauge  After withdraw"
        );

        // Chek widthraw OUT.
        uint256 balanceWithdrawn = testCommon.svcUSD().balanceOf(user);
        assertEq(balanceWithdrawn, 0, "balancesvcUsdAfter After withdraw");
        assertEq(
            testCommon.splitter().stableDepositTotal(),
            0,
            "stableDepositTotal After withdraw"
        );

        vm.stopPrank();
    }

    function test_withdraw_HalfLendStakeDaoAssetFromsvcUsd() external {
        // Setup.
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn, depositAmount);
        IERC20 stakeLiquidityGauge = IERC20(
            testCommon.stakeDaoLendVault().liquidityGauge()
        );

        // Check the initial.
        assertEq(testCommon.svcUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);
        assertEq(testCommon.crvUSD().balanceOf(user), depositAmount);

        // Deposit
        testCommon.deposit(depositAmount, true, true, tokenIn);
        uint256 expectedDeposit = testCommon.curvelendVault().convertToShares(
            depositAmount
        );

        // Check deposit.
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(),
            expectedDeposit,
            1 wei,
            "stableDepositTotal before withdraw"
        );
        uint256 balanceDeposited = testCommon.svcUSD().balanceOf(user);
        assertApproxEqAbs(
            balanceDeposited,
            expectedDeposit,
            1 wei,
            "balancesvcUsdBefore before withdraw"
        );
        assertEq(
            testCommon.crvUSD().balanceOf(user),
            0,
            "balance crvUSD  before withdraw"
        );

        // Advance in time.
        skip(100 days);

        // Withdraw.
        testCommon.widthraw(
            balanceDeposited / 2,
            true,
            LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset
        );

        // Chek widthraw IN.
        uint256 balancescvUsdAfter = testCommon.svcUSD().balanceOf(user);
        assertApproxEqAbs(
            balancescvUsdAfter,
            balanceDeposited / 2,
            1 wei,
            "balance scvUsd  After withdraw"
        );
        assertApproxEqAbs(
            balanceDeposited / 2,
            stakeLiquidityGauge.balanceOf(user),
            1 wei,
            "balance crvUSD  After withdraw"
        );

        // Chek widthraw OUT.
        uint256 balanceWithdrawn = testCommon.svcUSD().balanceOf(user);
        assertApproxEqAbs(
            balanceWithdrawn,
            balanceDeposited / 2,
            1 wei,
            "balancesvcUsdAfter After withdraw"
        );
        assertApproxEqAbs(
            testCommon.splitter().stableDepositTotal(),
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

        assertEq(testCommon.svcUSD().balanceOf(user), 0);
        assertEq(testCommon.curvelendVault().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);

        testCommon.deposit(depositAmount, true, true, tokenIn);

        uint256 overWithDraw = testCommon.curvelendVault().convertToShares(
            100 ether
        );
        vm.expectRevert();
        testCommon.widthraw(
            overWithDraw,
            true,
            LendRewardSplitter.TOKEN_TYPE.LendAsset
        );
    }

    function test_revertWhen_WithdrawLendCurveAssetWithNotEnoughBalance()
        external
    {
        uint256 depositAmount = 50 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn);

        assertEq(testCommon.svcUSD().balanceOf(user), 0);
        assertEq(testCommon.curvelendVault().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);

        testCommon.deposit(depositAmount, true, true, tokenIn);
        uint256 overWithDraw = testCommon.curvelendVault().convertToShares(
            100 ether
        );
        vm.expectRevert();
        testCommon.widthraw(
            overWithDraw,
            true,
            LendRewardSplitter.TOKEN_TYPE.LendCurveAsset
        );
    }

    function test_revertWhen_WithdrawLendStakeAssetWithNotEnoughBalance()
        external
    {
        uint256 depositAmount = 10 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn);

        assertEq(testCommon.svcUSD().balanceOf(user), 0);
        assertEq(testCommon.curvelendVault().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);

        testCommon.deposit(depositAmount, true, true, tokenIn);
        uint256 overWithDraw = testCommon.curvelendVault().convertToShares(
            100 ether
        );

        vm.expectRevert();
        testCommon.widthraw(
            overWithDraw,
            true,
            LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset
        );
    }
}
