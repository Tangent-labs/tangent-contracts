import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {IStakeDaoVault} from "../../src/interfaces/externals/IStakeDaoVault.sol";
import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20} from "../../src/libs/Resources.sol";

contract LendRewardSplitterGovDepositTest is Test {
    LendRewardSplitter splitter;

    LendRewardSplitterTestCommon testCommon = new LendRewardSplitterTestCommon();

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        testCommon.setUpSplitter();
        splitter = testCommon.splitter();
    }

    function test_deposit_LendassetWithGovRewardDepositEnabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = AddrClassicERC20.TOKEN_CRVUSD;
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.gUSDImplem().balanceOf(user), 0);
        assertEq(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), 0);

        testCommon.deposit(depositAmount, false, true, tokenIn);
        assertApproxEqAbs(testCommon.gUSDImplem().balanceOf(user), depositAmount, 1 wei);

        assertApproxEqAbs(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), depositAmount, 1 wei);
        assertEq(testCommon.stakeDaoVault().incentiveTokenAmount(), 0 ether);
    }

    function test_deposit_LendassetWithGovRewardDepositDisabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = AddrClassicERC20.TOKEN_CRVUSD;
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.gUSDImplem().balanceOf(user), 0);
        uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();

        assertEq(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), 0);
        testCommon.deposit(depositAmount, false, false, tokenIn);
        incentive = testCommon.stakeDaoVault().incentiveTokenAmount();
        incentive = testCommon.curveLendVault().convertToAssets(incentive);

        assertGt(incentive, 0);

        assertApproxEqAbs(testCommon.gUSDImplem().balanceOf(user), depositAmount - incentive, 2);
    }

    function test_deposit_LendcurveassetWithGovRewardDepositEnabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = address(AddrLlamaLendVaults.CRVUSD_CRV);
        address user = testCommon.getUser(1, tokenIn);
        assertEq(testCommon.gUSDImplem().balanceOf(user), 0);
        assertEq(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), 0);
        testCommon.deposit(depositAmount, false, true, tokenIn);
        uint256 depositedAmount = testCommon.curveLendVault().convertToAssets(depositAmount);
        assertEq(testCommon.gUSDImplem().balanceOf(user), depositedAmount);

        assertEq(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), depositedAmount);
    }

    function test_deposit_LendcurveassetWithGovRewardDepositDisabled() external {
        uint256 depositAmount = 100 ether;
        address tokenIn = address(AddrLlamaLendVaults.CRVUSD_CRV);
        address user = testCommon.getUser(1, tokenIn);

        assertEq(testCommon.gUSDImplem().balanceOf(user), 0);
        assertEq(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), 0);

        testCommon.deposit(depositAmount, false, false, tokenIn);

        uint256 depositedAmount = testCommon.curveLendVault().convertToAssets(depositAmount);

        uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();
        incentive = testCommon.curveLendVault().convertToAssets(incentive);

        assertGt(incentive, 0);

        assertApproxEqAbs(testCommon.gUSDImplem().balanceOf(user), depositedAmount - incentive, 1 wei);

        assertApproxEqAbs(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), depositedAmount - incentive, 1 wei);
    }

    function test_deposit_LendstakeassetWithGovRewardDepositEnabled() external {
        uint256 depositAmount = 100 ether;
        IStakeDaoVault tokenIn = AddrSdtVaults.CRVUSD_CRV;
        address user = testCommon.getUser(1, address(tokenIn));
        assertEq(testCommon.gUSDImplem().balanceOf(user), 0);
        assertEq(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), 0);
        testCommon.deposit(depositAmount, false, false, address(tokenIn));
        uint256 depositedAmount = testCommon.curveLendVault().convertToAssets(depositAmount);
        assertEq(testCommon.gUSDImplem().balanceOf(user), depositedAmount);

        assertEq(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), depositedAmount);
    }

    function test_deposit_LendstakeassetWithGovRewardDepositDisabled() external {
        uint256 depositAmount = 100 ether;
        IStakeDaoVault tokenIn = AddrSdtVaults.CRVUSD_CRV;
        address user = testCommon.getUser(1, address(tokenIn));
        assertEq(testCommon.gUSDImplem().balanceOf(user), 0);
        assertEq(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), 0);
        testCommon.deposit(depositAmount, false, false, address(tokenIn));
        uint256 depositedAmount = testCommon.curveLendVault().convertToAssets(depositAmount);

        uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();
        incentive = testCommon.curveLendVault().convertToAssets(incentive);

        assertEq(incentive, 0);
        assertApproxEqAbs(testCommon.gUSDImplem().balanceOf(user), depositedAmount, 1 wei);

        assertApproxEqAbs(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), depositedAmount, 1 wei);
    }
}
