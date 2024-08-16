import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {TokensvcUSD} from "../../src/tokens/TokensvcUSD.sol";
import {TokengUsd} from "../../src/tokens/TokengUsd.sol";
import {IStakeDaoVault} from "../../src/interfaces/IStakeDaoVault.sol";
import {ICurvelendVault} from "../../src/interfaces/ICurvelendVault.sol";

contract LendRewardSplitterStableDepositTest is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon;

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        splitter = testCommon.setUpSplitter();
    }

    function test_deposit_lendasset_with_stable_reward_deposit_enabled()
        external
    {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.svcUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);

        testCommon.deposit(depositAmount, true, true, tokenIn);
        assertEq(
            testCommon.svcUSD().balanceOf(user),
            testCommon.curvelendVault().convertToShares(depositAmount)
        );
        assertEq(
            testCommon.splitter().stableDepositTotal(),
            testCommon.curvelendVault().convertToShares(depositAmount)
        );
        assertEq(
            testCommon.stakeDaoLendVault().incentiveTokenAmount(),
            0 ether
        );
        vm.stopPrank();
    }

    function test_deposit_lendasset_with_stable_reward_deposit_disabled()
        external
    {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.TOKEN_crvUSD();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.svcUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);
        testCommon.deposit(depositAmount, true, false, tokenIn);
        uint256 incentive = testCommon
            .stakeDaoLendVault()
            .incentiveTokenAmount();
        assertGt(incentive, 0);
        assertEq(
            testCommon.svcUSD().balanceOf(user),
            testCommon.curvelendVault().convertToShares(depositAmount) -
                incentive,
            "balance user"
        );

        assertEq(
            testCommon.splitter().stableDepositTotal(),
            testCommon.curvelendVault().convertToShares(depositAmount) -
                incentive
        );

        vm.stopPrank();
    }

    function test_deposit_lendcurveasset_with_stable_reward_deposit_enabled()
        external
    {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.CURVE_CRV_VAULT();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.svcUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);
        testCommon.deposit(depositAmount, true, true, tokenIn);

        assertEq(
            testCommon.svcUSD().balanceOf(user),
            depositAmount,
            "balance user"
        );

        assertEq(testCommon.splitter().stableDepositTotal(), depositAmount);

        vm.stopPrank();
    }

    function test_deposit_lendcurveasset_with_stable_reward_deposit_disabled()
        external
    {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.CURVE_CRV_VAULT();
        address user = testCommon.getUser(1, tokenIn);

        assertEq(
            testCommon.svcUSD().balanceOf(user),
            0,
            "balanceOf user before"
        );
        assertEq(
            testCommon.splitter().stableDepositTotal(),
            0,
            "stableDepositTotal"
        );

        testCommon.deposit(depositAmount, true, false, tokenIn);

        uint256 incentive = testCommon
            .stakeDaoLendVault()
            .incentiveTokenAmount();

        assertGt(incentive, 0);
        assertEq(
            testCommon.svcUSD().balanceOf(user),
            depositAmount - incentive,
            "balance user after"
        );

        assertEq(
            testCommon.splitter().stableDepositTotal(),
            depositAmount - incentive
        );

        vm.stopPrank();
    }

    function test_deposit_lendstakeasset_with_stable_reward_deposit_enabled()
        external
    {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.STAKEDAO_CRV_VAULT();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.svcUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);
        testCommon.deposit(depositAmount, true, false, tokenIn);

        assertEq(
            testCommon.svcUSD().balanceOf(user),
            depositAmount,
            "balance user"
        );

        assertEq(testCommon.splitter().stableDepositTotal(), depositAmount);
        vm.stopPrank();
    }
    function test_deposit_lendstakeasset_with_stable_reward_deposit_disabled()
        external
    {
        uint256 depositAmount = 100 ether;
        address tokenIn = testCommon.STAKEDAO_CRV_VAULT();
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.svcUSD().balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);
        testCommon.deposit(depositAmount, true, false, tokenIn);
        uint256 incentive = testCommon
            .stakeDaoLendVault()
            .incentiveTokenAmount();
        assertEq(incentive, 0);
        assertEq(
            testCommon.svcUSD().balanceOf(user),
            depositAmount,
            "balance user"
        );

        assertEq(testCommon.splitter().stableDepositTotal(), depositAmount);

        vm.stopPrank();
    }

    // EDGE -------------------------------------------------------------------------------------

    function test_deposit_lendasset_with_stable_reward_deposit_enabled_without_enough_balance()
        external
    {
        uint256 depositAmount = 100 ether;
        address user = testCommon.getUser(1, testCommon.STAKEDAO_CRV_VAULT());
        assertEq(testCommon.svcUSD().balanceOf(user), 0);
        assertEq(IERC20(testCommon.TOKEN_crvUSD()).balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);
        vm.expectRevert();
        splitter.deposit(
            LendRewardSplitter.TOKEN_TYPE.LendAsset,
            depositAmount,
            true,
            true
        );
        vm.stopPrank();
    }
    function test_deposit_lendcurveasset_with_stable_reward_with_deposit_without_enough_balance()
        external
    {
        uint256 depositAmount = 100 ether;
        address user = testCommon.getUser(1, testCommon.TOKEN_crvUSD());
        assertEq(testCommon.svcUSD().balanceOf(user), 0);
        assertEq(IERC20(testCommon.CURVE_CRV_VAULT()).balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);
        vm.expectRevert();
        splitter.deposit(
            LendRewardSplitter.TOKEN_TYPE.LendCurveAsset,
            depositAmount,
            true,
            true
        );
        vm.stopPrank();
    }
    function test_deposit_lendstakeasset_with_stable_reward_deposit_enabled_without_enough_balance()
        external
    {
        uint256 depositAmount = 100 ether;
        address user = testCommon.getUser(1, testCommon.TOKEN_crvUSD());
        assertEq(testCommon.svcUSD().balanceOf(user), 0);
        assertEq(IERC20(testCommon.STAKEDAO_CRV_VAULT()).balanceOf(user), 0);
        assertEq(testCommon.splitter().stableDepositTotal(), 0);
        vm.expectRevert();
        splitter.deposit(
            LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset,
            depositAmount,
            true,
            true
        );
        vm.stopPrank();
    }
    function test_deposit_with_0() external {
        uint256 depositAmount = 0 ether;
        address user = testCommon.getUser(1, testCommon.TOKEN_crvUSD());

        vm.expectRevert();
        splitter.deposit(
            LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset,
            depositAmount,
            true,
            true
        );
        vm.stopPrank();
    }
    function test_deposit_with_not_existing_token_type_in() external {
        uint256 depositAmount = 0 ether;
        address user = testCommon.getUser(1, testCommon.TOKEN_crvUSD());
        vm.expectRevert();
        uint8 invalidEnumValue = 255;
        splitter.deposit(
            LendRewardSplitter.TOKEN_TYPE(invalidEnumValue),
            depositAmount,
            true,
            true
        );
        vm.stopPrank();
    }
    function test_deposit_with_more_than_maxint() external {
        uint256 depositAmount = testCommon.MAX_INT();
        address user = testCommon.getUser(1, testCommon.TOKEN_crvUSD());
        vm.expectRevert();
        splitter.deposit(
            LendRewardSplitter.TOKEN_TYPE.LendAsset,
            depositAmount + 1,
            true,
            true
        );
        vm.stopPrank();
    }
}
