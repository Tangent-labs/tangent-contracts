import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {TokensvcUSD} from "../../src/tokens/TokensvcUSD.sol";
import {TokengUsd} from "../../src/tokens/TokengUsd.sol";
import {IStakeDaoVault} from "../../src/interfaces/IStakeDaoVault.sol";
import {ICurvelendVault} from "../../src/interfaces/ICurvelendVault.sol";

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
        assertEq(testCommon.splitter().govDepositTotal(), 0);

        testCommon.deposit(depositAmount, false, true, tokenIn);
        assertApproxEqAbs(testCommon.gUSD().balanceOf(user), depositAmount, 1 wei);
        assertApproxEqAbs(testCommon.splitter().govDepositTotal(), depositAmount, 1 wei);
        assertEq(testCommon.stakeDaoLendVault().incentiveTokenAmount(), 0 ether);
        vm.stopPrank();
    }

    function test_deposit_LendassetWithGovRewardDepositDisabled() external {
        uint256 depositAmount = 100 ether; 
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.gUSD().balanceOf(user), 0);
        uint256 incentive = testCommon.stakeDaoLendVault().incentiveTokenAmount();
        assertEq(testCommon.splitter().govDepositTotal(), 0);
        testCommon.deposit(depositAmount, false, false, tokenIn);
        incentive = testCommon.stakeDaoLendVault().incentiveTokenAmount();
        incentive = testCommon.curvelendVault().convertToAssets(incentive);

        assertGt(incentive, 0);

        assertApproxEqAbs(testCommon.gUSD().balanceOf(user), depositAmount - incentive, 1 wei);

        vm.stopPrank();
    }

    function test_deposit_LendcurveassetWithGovRewardDepositEnabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.CURVE_CRV_VAULT();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.gUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().govDepositTotal(), 0);
        testCommon.deposit(depositAmount, false, true, tokenIn);
        uint256 depositedAmount = testCommon.curvelendVault().convertToAssets(depositAmount);
        assertEq(testCommon.gUSD().balanceOf(user), depositedAmount);

        assertEq(testCommon.splitter().govDepositTotal(), depositedAmount);

        vm.stopPrank();
    }

    function test_deposit_LendcurveassetWithGovRewardDepositDisabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.CURVE_CRV_VAULT();
        address user = testCommon.getUser(1, tokenIn);

        assertEq(testCommon.gUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().govDepositTotal(), 0);

        testCommon.deposit(depositAmount, false, false, tokenIn);

        uint256 depositedAmount = testCommon.curvelendVault().convertToAssets(depositAmount);

        uint256 incentive = testCommon.stakeDaoLendVault().incentiveTokenAmount();
        incentive = testCommon.curvelendVault().convertToAssets(incentive);

        assertGt(incentive, 0);

        assertApproxEqAbs(testCommon.gUSD().balanceOf(user), depositedAmount - incentive, 1 wei);

        assertApproxEqAbs(testCommon.splitter().govDepositTotal(), depositedAmount - incentive, 1 wei);

        vm.stopPrank();
    }

    function test_deposit_LendstakeassetWithGovRewardDepositEnabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.STAKEDAO_CRV_VAULT();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.gUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().govDepositTotal(), 0);
        testCommon.deposit(depositAmount, false, false, tokenIn);
        uint256 depositedAmount = testCommon.curvelendVault().convertToAssets(depositAmount);
        assertEq(testCommon.gUSD().balanceOf(user), depositedAmount);

        assertEq(testCommon.splitter().govDepositTotal(), depositedAmount);
        vm.stopPrank();
    }

    function test_deposit_LendstakeassetWithGovRewardDepositDisabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.STAKEDAO_CRV_VAULT();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.gUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().govDepositTotal(), 0);
        testCommon.deposit(depositAmount, false, false, tokenIn);
        uint256 depositedAmount = testCommon.curvelendVault().convertToAssets(depositAmount);

        uint256 incentive = testCommon.stakeDaoLendVault().incentiveTokenAmount();
        incentive = testCommon.curvelendVault().convertToAssets(incentive);

        assertEq(incentive, 0);
        assertApproxEqAbs(testCommon.gUSD().balanceOf(user), depositedAmount, 1 wei);

        assertApproxEqAbs(testCommon.splitter().govDepositTotal(), depositedAmount, 1 wei);

        vm.stopPrank();
    }
}
