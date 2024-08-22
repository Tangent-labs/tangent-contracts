import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {Addresses} from "../../src/libs/Addresses.sol";

contract LendRewardSplitterStableDepositTest is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon;

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        splitter = testCommon.setUpSplitter();
    }

    function test_deposit_LendassetWithStableRewardDepositEnabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);

        testCommon.deposit(depositAmount, true, true, tokenIn);
        assertEq(testCommon.scvUSD().balanceOf(user), testCommon.curveLendVault().convertToShares(depositAmount));
        assertEq(
            testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT),
            testCommon.curveLendVault().convertToShares(depositAmount)
        );
        assertEq(testCommon.stakeDaoVault().incentiveTokenAmount(), 0 ether);
        vm.stopPrank();
    }

    function test_deposit_LendassetWithStableRewardDepositDisabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        testCommon.deposit(depositAmount, true, false, tokenIn);
        uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();
        assertGt(incentive, 0);
        assertEq(
            testCommon.scvUSD().balanceOf(user),
            testCommon.curveLendVault().convertToShares(depositAmount) - incentive,
            "balance user"
        );

        assertEq(
            testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT),
            testCommon.curveLendVault().convertToShares(depositAmount) - incentive
        );

        vm.stopPrank();
    }

    function test_deposit_LendcurveassetWithStableRewardDepositEnabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.CURVE_CRV_VAULT();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        testCommon.deposit(depositAmount, true, true, tokenIn);

        assertEq(testCommon.scvUSD().balanceOf(user), depositAmount, "balance user");

        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), depositAmount);

        vm.stopPrank();
    }

    function test_deposit_LendcurveassetWithStableRewardDepositDisabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.CURVE_CRV_VAULT();
        address user = testCommon.getUser(1, tokenIn);

        assertEq(testCommon.scvUSD().balanceOf(user), 0, "balanceOf user before");
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0, "stableDepositTotal");

        testCommon.deposit(depositAmount, true, false, tokenIn);

        uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();

        assertGt(incentive, 0);
        assertEq(testCommon.scvUSD().balanceOf(user), depositAmount - incentive, "balance user after");

        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), depositAmount - incentive);

        vm.stopPrank();
    }

    function test_deposit_LendstakeassetWithStableRewardDepositEnabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.STAKEDAO_CRV_VAULT();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        testCommon.deposit(depositAmount, true, false, tokenIn);

        assertEq(testCommon.scvUSD().balanceOf(user), depositAmount, "balance user");

        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), depositAmount);
        vm.stopPrank();
    }
    function test_deposit_LendstakeassetWithStableRewardDepositDisabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.STAKEDAO_CRV_VAULT();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        testCommon.deposit(depositAmount, true, false, tokenIn);
        uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();
        assertEq(incentive, 0);
        assertEq(testCommon.scvUSD().balanceOf(user), depositAmount, "balance user");

        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), depositAmount);

        vm.stopPrank();
    }

    // EDGE -------------------------------------------------------------------------------------

    function test_revertWhen_depositLendassetWithStableRewardDepositEnabledWithoutEnoughBalance() external {
        uint256 depositAmount = 100 ether;
        address user = testCommon.getUser(1, testCommon.STAKEDAO_CRV_VAULT());
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(IERC20(testCommon.TOKEN_crvUSD()).balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        vm.expectRevert();
        splitter.deposit(
            Addresses.STAKEDAO_CRV_VAULT,
            LendRewardSplitter.TOKEN_TYPE.LendAsset,
            depositAmount,
            true,
            true
        );
        vm.stopPrank();
    }
    function test_revertWhen_depositLendcurveassetWithStableRewardWithDepositWithoutEnoughBalance() external {
        uint256 depositAmount = 100 ether;
        address user = testCommon.getUser(1, testCommon.TOKEN_crvUSD());
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(IERC20(testCommon.CURVE_CRV_VAULT()).balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        vm.expectRevert();
        splitter.deposit(
            Addresses.STAKEDAO_CRV_VAULT,
            LendRewardSplitter.TOKEN_TYPE.LendCurveAsset,
            depositAmount,
            true,
            true
        );
        vm.stopPrank();
    }
    function test_revertWhen_depositLendstakeassetWithStableRewardDepositEnabledWithoutEnoughBalance() external {
        uint256 depositAmount = 100 ether;
        address user = testCommon.getUser(1, testCommon.TOKEN_crvUSD());
        assertEq(testCommon.scvUSD().balanceOf(user), 0);
        assertEq(IERC20(testCommon.STAKEDAO_CRV_VAULT()).balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        vm.expectRevert();
        splitter.deposit(
            Addresses.STAKEDAO_CRV_VAULT,
            LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset,
            depositAmount,
            true,
            true
        );
        vm.stopPrank();
    }
    function test_revertWhen_depositWith0() external {
        uint256 depositAmount = 0 ether;
        testCommon.getUser(1, testCommon.TOKEN_crvUSD());

        vm.expectRevert();
        splitter.deposit(
            Addresses.STAKEDAO_CRV_VAULT,
            LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset,
            depositAmount,
            true,
            true
        );
        vm.stopPrank();
    }
    function test_revertWhen_depositWithNotExistingTokenTypeIn() external {
        uint256 depositAmount = 0 ether;
        testCommon.getUser(1, testCommon.TOKEN_crvUSD());
        vm.expectRevert();
        uint8 invalidEnumValue = 255;
        splitter.deposit(
            Addresses.STAKEDAO_CRV_VAULT,
            LendRewardSplitter.TOKEN_TYPE(invalidEnumValue),
            depositAmount,
            true,
            true
        );
        vm.stopPrank();
    }
    function test_revertWhen_depositWithMoreThanMaxint() external {
        uint256 depositAmount = testCommon.MAX_UINT();
        testCommon.getUser(1, testCommon.TOKEN_crvUSD());
        vm.expectRevert();
        splitter.deposit(
            Addresses.STAKEDAO_CRV_VAULT,
            LendRewardSplitter.TOKEN_TYPE.LendAsset,
            depositAmount + 1,
            true,
            true
        );
        vm.stopPrank();
    }
}
