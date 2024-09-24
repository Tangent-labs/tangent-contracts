import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {ILlamaLendVault} from "../../src/interfaces/externals/ILlamaLendVault.sol";
import {IStakeDaoVault} from "../../src/interfaces/externals/IStakeDaoVault.sol";
import {ILendRewardSplitter} from "../../src/interfaces/internals/ILendRewardSplitter.sol";
import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20} from "../../src/libs/Resources.sol";

contract SdtStableDepositTest is Test {
    LendRewardSplitter splitter;
    LendRewardSplitterTestCommon testCommon;

    ILlamaLendVault constant llamaVault = AddrLlamaLendVaults.CRVUSD_CRV; 

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();
    }

    function test_deposit_LendAsset_With_StableReward_DepositEnabled() external {
        uint256 depositAmount = 100 ether;
        IERC20 tokenIn = AddrClassicERC20.TOKEN_CRVUSD;
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.scvUSDImplem().balanceOf(user), 0);
        assertEq(testCommon.splitter().scvUSDSdtPerLlamaVault(llamaVault).totalSupply(), 0);

        vm.prank(user);
        splitter.depositSdt(llamaVault, ILendRewardSplitter.SDT_TOKEN_TYPE.LendAsset, depositAmount, true, true);


        assertEq(testCommon.scvUSDImplem().balanceOf(user), testCommon.curveLendVault().convertToShares(depositAmount));
        assertEq(
            testCommon.splitter().scvUSDSdtPerLlamaVault(llamaVault).totalSupply(),
            testCommon.curveLendVault().convertToShares(depositAmount)
        );
        assertEq(testCommon.stakeDaoVault().incentiveTokenAmount(), 0 ether);
    }

    function test_deposit_LendAsset_With_StableReward_DepositDisabled() external {
        uint256 depositAmount = 100 ether;
        IERC20 tokenIn = AddrClassicERC20.TOKEN_CRVUSD;
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.scvUSDImplem().balanceOf(user), 0);
        assertEq(testCommon.splitter().scvUSDSdtPerLlamaVault(llamaVault).totalSupply(), 0);


        vm.prank(user);
        splitter.depositSdt(llamaVault, ILendRewardSplitter.SDT_TOKEN_TYPE.LendAsset, depositAmount,true,false);


        uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();
        assertGt(incentive, 0);
        assertEq(testCommon.scvUSDImplem().balanceOf(user), testCommon.curveLendVault().convertToShares(depositAmount) - incentive, "balance user");

        assertEq(
            testCommon.splitter().scvUSDSdtPerLlamaVault(llamaVault).totalSupply(),
            testCommon.curveLendVault().convertToShares(depositAmount) - incentive
        );

    }

    function test_deposit_LendLlamaVaultAsset_With_StableReward_DepositEnabled() external {
        uint256 depositAmount = 100 ether;

        address user = testCommon.getUser(1, llamaVault);
        assertEq(testCommon.scvUSDImplem().balanceOf(user), 0);
        assertEq(testCommon.splitter().scvUSDSdtPerLlamaVault(llamaVault).totalSupply(), 0);

        vm.prank(user);
        splitter.depositSdt(llamaVault, ILendRewardSplitter.SDT_TOKEN_TYPE.LlamalendVaultAsset, depositAmount, true, true);

        assertEq(testCommon.scvUSDImplem().balanceOf(user), depositAmount, "balance user");

        assertEq(testCommon.splitter().scvUSDSdtPerLlamaVault(llamaVault).totalSupply(), depositAmount);

    }

    function test_deposit_LendLlamaVaultAsset_With_StableReward_DepositDisabled() external {
        uint256 depositAmount = 100 ether;
        address user = testCommon.getUser(1, llamaVault);

        assertEq(testCommon.scvUSDImplem().balanceOf(user), 0, "balanceOf user before");
        assertEq(testCommon.splitter().scvUSDSdtPerLlamaVault(llamaVault).totalSupply(), 0, "stableDepositTotal");

        vm.prank(user);
        splitter.depositSdt(llamaVault, ILendRewardSplitter.SDT_TOKEN_TYPE.LlamalendVaultAsset, depositAmount, true, false);

        uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();

        assertGt(incentive, 0);
        assertEq(testCommon.scvUSDImplem().balanceOf(user), depositAmount - incentive, "balance user after");

        assertEq(testCommon.splitter().scvUSDSdtPerLlamaVault(llamaVault).totalSupply(), depositAmount - incentive);

    }

    function test_deposit_SdtGaugeAsset_With_StableReward_DepositEnabled() external {
        uint256 depositAmount = 100 ether;
        IStakeDaoVault tokenIn = AddrSdtVaults.CRVUSD_CRV;
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.scvUSDImplem().balanceOf(user), 0);
        assertEq(testCommon.splitter().scvUSDSdtPerLlamaVault(llamaVault).totalSupply(), 0);

        vm.prank(user);
        splitter.depositSdt(llamaVault, ILendRewardSplitter.SDT_TOKEN_TYPE.SdtGaugeAsset, depositAmount, true, false);

        assertEq(testCommon.scvUSDImplem().balanceOf(user), depositAmount, "balance user");

        assertEq(testCommon.splitter().scvUSDSdtPerLlamaVault(llamaVault).totalSupply(), depositAmount);
    }

    function test_deposit_SdtGaugeAsset_With_StableReward_DepositDisabled() external {
        uint256 depositAmount = 100 ether;
        IStakeDaoVault tokenIn = AddrSdtVaults.CRVUSD_CRV;
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.scvUSDImplem().balanceOf(user), 0);
        assertEq(testCommon.splitter().scvUSDSdtPerLlamaVault(llamaVault).totalSupply(), 0);

        vm.prank(user);
        splitter.depositSdt(llamaVault, ILendRewardSplitter.SDT_TOKEN_TYPE.SdtGaugeAsset, depositAmount, true, false);

        uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();
        assertEq(incentive, 0);
        assertEq(testCommon.scvUSDImplem().balanceOf(user), depositAmount, "balance user");

        assertEq(testCommon.splitter().scvUSDSdtPerLlamaVault(llamaVault).totalSupply(), depositAmount);


    }

    // // EDGE -------------------------------------------------------------------------------------

    // function test_revertWhen_depositLendassetWithStableRewardDepositEnabledWithoutEnoughBalance() external {
    //     uint256 depositAmount = 100 ether;
    //     address user = testCommon.getUser(1, AddrSdtVaults.CRVUSD_CRV);
    //     assertEq(testCommon.scvUSDImplem().balanceOf(user), 0);
    //     assertEq(IERC20(AddrClassicERC20.TOKEN_CRVUSD).balanceOf(user), 0);
    //     assertEq(testCommon.splitter().scvUSDSdtPerLlamaVault(llamaVault).totalSupply(), 0);
    //     vm.expectRevert();
    //     splitter.depositSdt(llamaVault, ILendRewardSplitter.SDT_TOKEN_TYPE.LendAsset, depositAmount, true, true);
    //     vm.stopPrank();
    // }

    // function test_revertWhen_depositLendcurveassetWithStableRewardWithDepositWithoutEnoughBalance() external {
    //     uint256 depositAmount = 100 ether;
    //     address user = testCommon.getUser(1, AddrClassicERC20.TOKEN_CRVUSD);
    //     assertEq(testCommon.scvUSDImplem().balanceOf(user), 0);
    //     assertEq(IERC20(llamaVault).balanceOf(user), 0);
    //     assertEq(testCommon.splitter().scvUSDSdtPerLlamaVault(llamaVault).totalSupply(), 0);
    //     vm.expectRevert();
    //     splitter.depositSdt(llamaVault, ILendRewardSplitter.SDT_TOKEN_TYPE.LlamalendVaultAsset, depositAmount, true, true);
    //     vm.stopPrank();
    // }

    // function test_revertWhen_depositLendstakeassetWithStableRewardDepositEnabledWithoutEnoughBalance() external {
    //     uint256 depositAmount = 100 ether;
    //     address user = testCommon.getUser(1, AddrClassicERC20.TOKEN_CRVUSD);
    //     assertEq(testCommon.scvUSDImplem().balanceOf(user), 0);
    //     assertEq(IERC20(AddrSdtVaults.CRVUSD_CRV).balanceOf(user), 0);
    //     assertEq(testCommon.splitter().scvUSDSdtPerLlamaVault(llamaVault).totalSupply(), 0);
    //     vm.expectRevert();
    //     splitter.depositSdt(llamaVault, ILendRewardSplitter.SDT_TOKEN_TYPE.SdtGaugeAsset, depositAmount, true, true);
    //     vm.stopPrank();
    // }

    // function test_revertWhen_depositWith0() external {
    //     uint256 depositAmount = 0 ether;
    //     testCommon.getUser(1, AddrClassicERC20.TOKEN_CRVUSD);

    //     vm.expectRevert();
    //     splitter.depositSdt(llamaVault, ILendRewardSplitter.SDT_TOKEN_TYPE.SdtGaugeAsset, depositAmount, true, true);
    //     vm.stopPrank();
    // }

    // function test_revertWhen_depositWithNotExistingTokenTypeIn() external {
    //     uint256 depositAmount = 0 ether;
    //     testCommon.getUser(1, AddrClassicERC20.TOKEN_CRVUSD);
    //     vm.expectRevert();
    //     uint8 invalidEnumValue = 255;
    //     splitter.depositSdt(llamaVault, ILendRewardSplitter.SDT_TOKEN_TYPE(invalidEnumValue), depositAmount, true, true);
    //     vm.stopPrank();
    // }

    // function test_revertWhen_depositWithMoreThanMaxint() external {
    //     uint256 depositAmount = testCommon.MAX_UINT();
    //     testCommon.getUser(1, AddrClassicERC20.TOKEN_CRVUSD);
    //     vm.expectRevert();
    //     splitter.depositSdt(llamaVault, ILendRewardSplitter.SDT_TOKEN_TYPE.LendAsset, depositAmount + 1, true, true);
    //     vm.stopPrank();
    // }
}
