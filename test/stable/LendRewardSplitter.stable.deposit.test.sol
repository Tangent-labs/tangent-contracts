import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {Addr} from "../../src/libs/Addr.sol";

contract LendRewardSplitterStableDepositTest is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon;

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();
    }

    function test_deposit_LendassetWithStableRewardDepositEnabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = Addr.TOKEN_CRVUSD;
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addr.STAKEDAO_CRVUSD_CRV), 0);

        testCommon.deposit(depositAmount, true, true, tokenIn);
        assertEq(testCommon.scvUSD().balanceOf(user), testCommon.curveLendVault().convertToShares(depositAmount));
        assertEq(
            testCommon.splitter().stableDepositTotal(Addr.STAKEDAO_CRVUSD_CRV),
            testCommon.curveLendVault().convertToShares(depositAmount)
        );
        assertEq(testCommon.stakeDaoVault().incentiveTokenAmount(), 0 ether);
        vm.stopPrank();
    }

    function test_deposit_LendassetWithStableRewardDepositDisabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = Addr.TOKEN_CRVUSD;
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addr.STAKEDAO_CRVUSD_CRV), 0);
        testCommon.deposit(depositAmount, true, false, tokenIn);
        uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();
        assertGt(incentive, 0);
        assertEq(
            testCommon.scvUSD().balanceOf(user),
            testCommon.curveLendVault().convertToShares(depositAmount) - incentive,
            "balance user"
        );

        assertEq(
            testCommon.splitter().stableDepositTotal(Addr.STAKEDAO_CRVUSD_CRV),
            testCommon.curveLendVault().convertToShares(depositAmount) - incentive
        );

        vm.stopPrank();
    }

    function test_deposit_LendcurveassetWithStableRewardDepositEnabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = Addr.CURVE_CRV_VAULT;
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addr.STAKEDAO_CRVUSD_CRV), 0);
        testCommon.deposit(depositAmount, true, true, tokenIn);

        assertEq(testCommon.scvUSD().balanceOf(user), depositAmount, "balance user");

        assertEq(testCommon.splitter().stableDepositTotal(Addr.STAKEDAO_CRVUSD_CRV), depositAmount);

        vm.stopPrank();
    }

    function test_deposit_LendcurveassetWithStableRewardDepositDisabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = Addr.CURVE_CRV_VAULT;
        address user = testCommon.getUser(1, tokenIn);

        assertEq(testCommon.scvUSD().balanceOf(user), 0, "balanceOf user before");
        assertEq(testCommon.splitter().stableDepositTotal(Addr.STAKEDAO_CRVUSD_CRV), 0, "stableDepositTotal");

        testCommon.deposit(depositAmount, true, false, tokenIn);

        uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();

        assertGt(incentive, 0);
        assertEq(testCommon.scvUSD().balanceOf(user), depositAmount - incentive, "balance user after");

        assertEq(testCommon.splitter().stableDepositTotal(Addr.STAKEDAO_CRVUSD_CRV), depositAmount - incentive);

        vm.stopPrank();
    }

    function test_deposit_LendstakeassetWithStableRewardDepositEnabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = Addr.STAKEDAO_CRVUSD_CRV;
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addr.STAKEDAO_CRVUSD_CRV), 0);
        testCommon.deposit(depositAmount, true, false, tokenIn);

        assertEq(testCommon.scvUSD().balanceOf(user), depositAmount, "balance user");

        assertEq(testCommon.splitter().stableDepositTotal(Addr.STAKEDAO_CRVUSD_CRV), depositAmount);
        vm.stopPrank();
    }
    function test_deposit_LendstakeassetWithStableRewardDepositDisabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = Addr.STAKEDAO_CRVUSD_CRV;
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addr.STAKEDAO_CRVUSD_CRV), 0);
        testCommon.deposit(depositAmount, true, false, tokenIn);
        uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();
        assertEq(incentive, 0);
        assertEq(testCommon.scvUSD().balanceOf(user), depositAmount, "balance user");

        assertEq(testCommon.splitter().stableDepositTotal(Addr.STAKEDAO_CRVUSD_CRV), depositAmount);

        vm.stopPrank();
    }

    // EDGE -------------------------------------------------------------------------------------

    function test_revertWhen_depositLendassetWithStableRewardDepositEnabledWithoutEnoughBalance() external {
        uint256 depositAmount = 100 ether;
        address user = testCommon.getUser(1, Addr.STAKEDAO_CRVUSD_CRV);
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(IERC20(Addr.TOKEN_CRVUSD).balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addr.STAKEDAO_CRVUSD_CRV), 0);
        vm.expectRevert();
        splitter.deposit(Addr.STAKEDAO_CRVUSD_CRV, LendRewardSplitter.TOKEN_TYPE.LendAsset, depositAmount, true, true);
        vm.stopPrank();
    }
    function test_revertWhen_depositLendcurveassetWithStableRewardWithDepositWithoutEnoughBalance() external {
        uint256 depositAmount = 100 ether;
        address user = testCommon.getUser(1, Addr.TOKEN_CRVUSD);
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(IERC20(Addr.CURVE_CRV_VAULT).balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addr.STAKEDAO_CRVUSD_CRV), 0);
        vm.expectRevert();
        splitter.deposit(
            Addr.STAKEDAO_CRVUSD_CRV,
            LendRewardSplitter.TOKEN_TYPE.LendCurveAsset,
            depositAmount,
            true,
            true
        );
        vm.stopPrank();
    }
    function test_revertWhen_depositLendstakeassetWithStableRewardDepositEnabledWithoutEnoughBalance() external {
        uint256 depositAmount = 100 ether;
        address user = testCommon.getUser(1, Addr.TOKEN_CRVUSD);
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(IERC20(Addr.STAKEDAO_CRVUSD_CRV).balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addr.STAKEDAO_CRVUSD_CRV), 0);
        vm.expectRevert();
        splitter.deposit(
            Addr.STAKEDAO_CRVUSD_CRV,
            LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset,
            depositAmount,
            true,
            true
        );
        vm.stopPrank();
    }
    function test_revertWhen_depositWith0() external {
        uint256 depositAmount = 0 ether;
        testCommon.getUser(1, Addr.TOKEN_CRVUSD);

        vm.expectRevert();
        splitter.deposit(
            Addr.STAKEDAO_CRVUSD_CRV,
            LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset,
            depositAmount,
            true,
            true
        );
        vm.stopPrank();
    }
    function test_revertWhen_depositWithNotExistingTokenTypeIn() external {
        uint256 depositAmount = 0 ether;
        testCommon.getUser(1, Addr.TOKEN_CRVUSD);
        vm.expectRevert();
        uint8 invalidEnumValue = 255;
        splitter.deposit(
            Addr.STAKEDAO_CRVUSD_CRV,
            LendRewardSplitter.TOKEN_TYPE(invalidEnumValue),
            depositAmount,
            true,
            true
        );
        vm.stopPrank();
    }
    function test_revertWhen_depositWithMoreThanMaxint() external {
        uint256 depositAmount = testCommon.MAX_UINT();
        testCommon.getUser(1, Addr.TOKEN_CRVUSD);
        vm.expectRevert();
        splitter.deposit(
            Addr.STAKEDAO_CRVUSD_CRV,
            LendRewardSplitter.TOKEN_TYPE.LendAsset,
            depositAmount + 1,
            true,
            true
        );
        vm.stopPrank();
    }
}
