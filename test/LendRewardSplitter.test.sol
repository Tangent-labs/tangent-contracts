import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitter} from "../src/LendRewardSplitter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TokensvcUSD} from "../src/tokens/TokensvcUSD.sol";
import {TokengUsd} from "../src/tokens/TokengUsd.sol";
import {IStakeDaoVault} from "../src/interfaces/IStakeDaoVault.sol";
import {ICurvelendVault} from "../src/interfaces/ICurvelendVault.sol";

contract LendRewardSplitterTest is Test {
    LendRewardSplitter splitter;

    uint256 MAX_INT = uint256(int256(-1));

    // lendAsset
    address TOKEN_crvUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    // Vaulted crvUSD
    address CURVE_CRV_VAULT = 0xCeA18a8752bb7e7817F9AE7565328FE415C0f2cA; // Vaulted cvcrvUSD
    // Vaulted crvUSD in stake DAO
    address STAKEDAO_CRV_VAULT = 0xfa6D40573082D797CB3cC378c0837fB90eB043e5;

    TokensvcUSD svcUSD;
    TokengUsd gUsd;
    IERC20 liquidityGauge;
    ICurvelendVault curvelendVault;


    function setUp() public {
        vm.createSelectFork("mainnet", 20513092);
        
        liquidityGauge = IERC20(
            IStakeDaoVault(STAKEDAO_CRV_VAULT).liquidityGauge()
        );
        curvelendVault = ICurvelendVault(CURVE_CRV_VAULT);

        svcUSD = new TokensvcUSD("CRV", STAKEDAO_CRV_VAULT);
        gUsd = new TokengUsd("CRV", STAKEDAO_CRV_VAULT);
        splitter = new LendRewardSplitter();

        svcUSD.setSplitterContract(address(splitter));
        gUsd.setSplitterContract(address(splitter));
        vm.label(TOKEN_crvUSD, "crvUSD");
        vm.label(STAKEDAO_CRV_VAULT, "STAKEDAO_CRV_VAULT");
        vm.label(CURVE_CRV_VAULT, "CURVE_CRV_VAULT");
        vm.label(
            IStakeDaoVault(STAKEDAO_CRV_VAULT).strategy(),
            "STAKEDAO_CRV_STRATEGY"
        );
        vm.label(
            IStakeDaoVault(STAKEDAO_CRV_VAULT).liquidityGauge(),
            "STAKEDAO_CRV_LIQUIDITY_GAUGE"
        );
        /*
            address _curveLendVault,
            address _stakeDaoVault,
            address _curveGauge
        */
        splitter.initialize(
            CURVE_CRV_VAULT,
            STAKEDAO_CRV_VAULT,
            address(gUsd),
            address(svcUSD)
        );
    }

    function testDepositStableLendAsset() external {
        address tokenIn = TOKEN_crvUSD;
        address user = _getUser(1, tokenIn);
        uint depositAmount = splitter.deposit(
            LendRewardSplitter.TOKEN_TYPE.LendAsset,
            1000 ether,
            true,
            true
        );
        vm.stopPrank();
        assertGt(depositAmount, 0);
        assertEq(IERC20(tokenIn).balanceOf(user), 0);
        assertEq(splitter.stableDepositTotal(), depositAmount);
        assertEq(splitter.govDepositTotal(), 0);
        assertEq(svcUSD.balanceOf(user), depositAmount);
        assertEq(liquidityGauge.balanceOf(address(splitter)), depositAmount);
    }

    function testDepositStableCurveLendAsset() external {
        address tokenIn = CURVE_CRV_VAULT;
        address user = _getUser(2, tokenIn);
        uint depositAmount = splitter.deposit(
            LendRewardSplitter.TOKEN_TYPE.LendCurveAsset,
            1000 ether,
            true,
            true
        );
        vm.stopPrank();
        assertGt(depositAmount, 0);
        assertEq(IERC20(tokenIn).balanceOf(user), 0);
        assertEq(splitter.stableDepositTotal(), depositAmount);
        assertEq(splitter.govDepositTotal(), 0);
        assertEq(svcUSD.balanceOf(user), depositAmount);
        assertEq(liquidityGauge.balanceOf(address(splitter)), depositAmount);
    }

    function testDepositStableStakeDaoLendAsset() external {
        address tokenIn = STAKEDAO_CRV_VAULT;
        address user = _getUser(3, tokenIn);
        uint depositAmount = splitter.deposit(
            LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset,
            1000 ether,
            true,
            true
        );
        vm.stopPrank();
        assertGt(depositAmount, 0);
        assertEq(IERC20(tokenIn).balanceOf(user), 0);
        assertEq(splitter.stableDepositTotal(), depositAmount);
        assertEq(splitter.govDepositTotal(), 0);
        assertEq(svcUSD.balanceOf(user), depositAmount);
        assertEq(liquidityGauge.balanceOf(address(splitter)), depositAmount);
    }

    function testDepositRewardLendAsset() external {
        address tokenIn = TOKEN_crvUSD;
        address user = _getUser(1, tokenIn);
        uint depositAmount = splitter.deposit(
            LendRewardSplitter.TOKEN_TYPE.LendAsset,
            1000 ether,
            false,
            true
        );
        vm.stopPrank();
        assertGt(depositAmount, 0);
        assertEq(IERC20(tokenIn).balanceOf(user), 0);
        assertEq(splitter.stableDepositTotal(), 0);
        assertEq(splitter.govDepositTotal(), depositAmount);
        assertEq(gUsd.balanceOf(user), depositAmount);
        assertApproxEqAbs(
            liquidityGauge.balanceOf(address(splitter)),
            curvelendVault.convertToShares(depositAmount),
            1000 wei
        );
    }

    function testDepositRewardCurveLendAsset() external {
        address tokenIn = CURVE_CRV_VAULT;
        address user = _getUser(2, tokenIn);
        uint depositAmount = splitter.deposit(
            LendRewardSplitter.TOKEN_TYPE.LendCurveAsset,
            1000 ether,
            false,
            true
        );
        vm.stopPrank();
        assertGt(depositAmount, 0);
        assertEq(IERC20(tokenIn).balanceOf(user), 0);
        assertEq(splitter.stableDepositTotal(), 0);
        assertEq(splitter.govDepositTotal(), depositAmount);
        assertEq(gUsd.balanceOf(user), depositAmount);
        assertApproxEqAbs(
            liquidityGauge.balanceOf(address(splitter)),
            curvelendVault.convertToShares(depositAmount),
            1000 wei
        );
    }

    function testDepositRewardStakeDaoLendAsset() external {
        address tokenIn = STAKEDAO_CRV_VAULT;
        address user = _getUser(3, tokenIn);
        uint depositAmount = splitter.deposit(
            LendRewardSplitter.TOKEN_TYPE.LendStakeDaoAsset,
            1000 ether,
            false,
            true
        );
        vm.stopPrank();
        assertGt(depositAmount, 0);
        assertEq(IERC20(tokenIn).balanceOf(user), 0);
        assertEq(splitter.stableDepositTotal(), 0);
        assertEq(splitter.govDepositTotal(), depositAmount);
        assertEq(gUsd.balanceOf(user), depositAmount);
        assertApproxEqAbs(
            liquidityGauge.balanceOf(address(splitter)),
            curvelendVault.convertToShares(depositAmount),
            1000 wei
        );
    }

    function testWithrawLendAssetFromgUsd() external {
        address tokenIn = TOKEN_crvUSD;
        address user = _getUser(2, tokenIn);
        assertEq(gUsd.balanceOf(user), 0);
        uint depositAmount = splitter.deposit(
            LendRewardSplitter.TOKEN_TYPE.LendAsset,
            10 ether,
            false,
            true
        );
        assertEq(gUsd.balanceOf(user), depositAmount);
        uint balancecrvUsdbefore = IERC20(TOKEN_crvUSD).balanceOf(user);
        uint balanceCURVE_CRV_VAULTbefore = IERC20(CURVE_CRV_VAULT).balanceOf(
            user
        );
        skip(3600);
        splitter.withdraw(
            LendRewardSplitter.TOKEN_TYPE.LendAsset,
            depositAmount,
            false
        );

        uint balancecrvUsdAfter = IERC20(TOKEN_crvUSD).balanceOf(user);
        uint balanceCURVE_CRV_VAULTafter = IERC20(CURVE_CRV_VAULT).balanceOf(
            user
        );
        assertEq(gUsd.balanceOf(user), 0);
        assertEq(
            balanceCURVE_CRV_VAULTafter - balanceCURVE_CRV_VAULTbefore,
            depositAmount
        );
        vm.stopPrank();
    }

    function _getUser(
        uint index,
        address token
    ) internal returns (address user) {
        user = makeAddr(string.concat("user", vm.toString((index))));
        vm.deal(user, 10 ether);
        if (token == STAKEDAO_CRV_VAULT) {
            token = IStakeDaoVault(STAKEDAO_CRV_VAULT).liquidityGauge();
        }
        vm.startPrank(user);
        deal(token, user, 1000 ether);
        IERC20(token).approve(address(splitter), MAX_INT);
    }
}

// function test_deposit_lendasset_with_stable_reward_deposit_enabled() external { }
// function test_deposit_lendasset_with_stable_reward_deposit_disabled() external { }
// function test_deposit_lendasset_with_gov_reward_deposit_enabled() external { }
// function test_deposit_lendasset_with_gov_reward_deposit_disabled() external { }
// function test_deposit_lendcurveasset_with_stable_reward_deposit_enabled() external { }
// function test_deposit_lendcurveasset_with_stable_reward_deposit_disabled_() external { }
// function test_deposit_lendcurveasset_with_gov_reward_deposit_enabled_() external { }
// function test_deposit_lendcurveasset_with_gov_reward_deposit_disabled_() external { }
// function test_deposit_lendstakeasset_with_stable_reward() external { }
// function test_deposit_lendstakeasset_with_gov_reward() external { }
// function test_deposit_lendasset_with_stable_reward_deposit_enabled_without_enough_balance() external { }
// function test_deposit_lendcurveasset_with_stable_reward_with_deposit_without_enough_balance() external { }
// function test_deposit_lendstakeasset_with_stable_reward_deposit_enabled_without_enough_balance() external { }
// function test_deposit_with_0() external { }
// function test_deposit_with_not_existing_token_type_in() external { }
// function test_deposit_with_more_than_maxint() external { }
// function test_withdraw_all_lendcurveasset_from_gusd() external { }
// function test_withdraw_all_lendcurveasset_from_scvusd() external { }
// function test_withdraw_all_lendasset_from_gusd() external { }
// function test_withdraw_all_lendasset_from_scvusd() external { }
// function test_withdraw_half_lendcurveasset_from_gusd() external { }
// function test_withdraw_half_lendcurveasset_from_scvusd() external { }
// function test_withdraw_half_lendasset_from_gusd() external { }
// function test_withdraw_half_lendasset_from_scvusd() external { }
// function test_withdraw_lendstakedaoasset_from_scvusd() external { }
// function test_withdraw_not_existing_type_from_scvusd__() external { }
// function test_withdraw_100_lendasset_from_scvusd() external { }
// function test_withdraw_100_lendasset_from_gusd() external { }
// function test_withdraw_10000_lendasset_from_gusd_when_all_supply_is_borrowed() external { }
// function test_deposit_withdraw_multi_user() external { }
