import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {Addresses} from "../../src/libs/Addresses.sol";

contract LendRewardSplitterGovDepositTest is Test {
    LendRewardSplitter splitter;

    LendRewardSplitterTestCommon testCommon = new LendRewardSplitterTestCommon();

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        splitter = testCommon.setUpSplitter();
    }

    function test_deposit_LendassetWithGovRewardDepositEnabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.gUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().govDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);

        testCommon.deposit(depositAmount, false, true, tokenIn);
        assertApproxEqAbs(testCommon.gUSD().balanceOf(user), depositAmount, 1 wei);
        assertApproxEqAbs(testCommon.splitter().govDepositTotal(Addresses.STAKEDAO_CRV_VAULT), depositAmount, 1 wei);
        assertEq(testCommon.stakeDaoVault().incentiveTokenAmount(), 0 ether);
        vm.stopPrank();
    }

    function test_deposit_LendassetWithGovRewardDepositDisabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.gUSD().balanceOf(user), 0);
        uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();
        assertEq(testCommon.splitter().govDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        testCommon.deposit(depositAmount, false, false, tokenIn);
        incentive = testCommon.stakeDaoVault().incentiveTokenAmount();
        incentive = testCommon.curveLendVault().convertToAssets(incentive);

        assertGt(incentive, 0);

        assertApproxEqAbs(testCommon.gUSD().balanceOf(user), depositAmount - incentive, 1 wei);

        vm.stopPrank();
    }

    function test_deposit_LendcurveassetWithGovRewardDepositEnabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.CURVE_CRV_VAULT();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.gUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().govDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        testCommon.deposit(depositAmount, false, true, tokenIn);
        uint256 depositedAmount = testCommon.curveLendVault().convertToAssets(depositAmount);
        assertEq(testCommon.gUSD().balanceOf(user), depositedAmount);

        assertEq(testCommon.splitter().govDepositTotal(Addresses.STAKEDAO_CRV_VAULT), depositedAmount);

        vm.stopPrank();
    }

    function test_deposit_LendcurveassetWithGovRewardDepositDisabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.CURVE_CRV_VAULT();
        address user = testCommon.getUser(1, tokenIn);

        assertEq(testCommon.gUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().govDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);

        testCommon.deposit(depositAmount, false, false, tokenIn);

        uint256 depositedAmount = testCommon.curveLendVault().convertToAssets(depositAmount);

        uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();
        incentive = testCommon.curveLendVault().convertToAssets(incentive);

        assertGt(incentive, 0);

        assertApproxEqAbs(testCommon.gUSD().balanceOf(user), depositedAmount - incentive, 1 wei);

        assertApproxEqAbs(
            testCommon.splitter().govDepositTotal(Addresses.STAKEDAO_CRV_VAULT),
            depositedAmount - incentive,
            1 wei
        );

        vm.stopPrank();
    }

    function test_deposit_LendstakeassetWithGovRewardDepositEnabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.STAKEDAO_CRV_VAULT();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.gUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().govDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        testCommon.deposit(depositAmount, false, false, tokenIn);
        uint256 depositedAmount = testCommon.curveLendVault().convertToAssets(depositAmount);
        assertEq(testCommon.gUSD().balanceOf(user), depositedAmount);

        assertEq(testCommon.splitter().govDepositTotal(Addresses.STAKEDAO_CRV_VAULT), depositedAmount);
        vm.stopPrank();
    }

    function test_deposit_LendstakeassetWithGovRewardDepositDisabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.STAKEDAO_CRV_VAULT();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.gUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().govDepositTotal(Addresses.STAKEDAO_CRV_VAULT), 0);
        testCommon.deposit(depositAmount, false, false, tokenIn);
        uint256 depositedAmount = testCommon.curveLendVault().convertToAssets(depositAmount);

        uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();
        incentive = testCommon.curveLendVault().convertToAssets(incentive);

        assertEq(incentive, 0);
        assertApproxEqAbs(testCommon.gUSD().balanceOf(user), depositedAmount, 1 wei);

        assertApproxEqAbs(testCommon.splitter().govDepositTotal(Addresses.STAKEDAO_CRV_VAULT), depositedAmount, 1 wei);

        vm.stopPrank();
    }
}
