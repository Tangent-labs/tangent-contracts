// import {Test, console} from "forge-std/Test.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import {DeployContext} from "../DeployContext.sol";
// import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
// import {IStakeDaoVault} from "../../src/interfaces/externals/IStakeDaoVault.sol";
// import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20, ILlamaVault, ISdtLiquidityGauge} from "../../src/libs/Resources.sol";

// contract LendRewardSplitterGovDepositTest is Test {
//     LendRewardSplitter splitter;

//     DeployContext testCommon = new DeployContext();

//     IERC20 constant CRVUSD = AddrClassicERC20.TOKEN_CRVUSD;
//     ILlamaVault constant LLAMALEND_VAULT_CRVUSD = AddrLlamaLendVaults.CRVUSD_CRV;
//     ISdtLiquidityGauge constant STAKEDAO_GAUGE_CRVUSD = AddrSdtGauges.CRVUSD_CRV;
//     ISdtVault constant STAKEDAO_GAUGE_CRVUSD = AddrSdtGauges.CRVUSD_CRV;
//     function setUp() public {
//         testCommon = new DeployContext();
//         testCommon.fork();
//         testCommon.setUpSplitter();
//         splitter = testCommon.splitter();
//     }

//     function test_deposit_LendassetWithGovRewardDepositEnabled() external {
//         uint256 depositAmount = 100 ether;

//         address user = testCommon.getUser(1, CRVUSD);
//         assertEq(testCommon.gUSDImplem().balanceOf(user), 0);
//         assertEq(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), 0);

//         testCommon.deposit(depositAmount, false, true, CRVUSD);
//         assertApproxEqAbs(testCommon.gUSDImplem().balanceOf(user), depositAmount, 1 wei);

//         assertApproxEqAbs(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), depositAmount, 1 wei);
//         assertEq(testCommon.stakeDaoVault().incentiveTokenAmount(), 0 ether);
//     }

//     function test_deposit_LendassetWithGovRewardDepositDisabled() external {
//         uint256 depositAmount = 100 ether;

//         address user = testCommon.getUser(1, CRVUSD);
//         assertEq(testCommon.gUSDImplem().balanceOf(user), 0);
//         uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();

//         assertEq(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), 0);
//         testCommon.deposit(depositAmount, false, false, CRVUSD);
//         incentive = testCommon.stakeDaoVault().incentiveTokenAmount();
//         incentive = testCommon.curveLendVault().convertToAssets(incentive);

//         assertGt(incentive, 0);

//         assertApproxEqAbs(testCommon.gUSDImplem().balanceOf(user), depositAmount - incentive, 2);
//     }

//     function test_deposit_LendcurveassetWithGovRewardDepositEnabled() external {
//         uint256 depositAmount = 100 ether;
//         address user = testCommon.getUser(1, LLAMALEND_VAULT_CRVUSD);
//         assertEq(testCommon.gUSDImplem().balanceOf(user), 0);
//         assertEq(testCommon.splitter().gUSDSdtPerLlamaVault(LLAMALEND_VAULT_CRVUSD).totalSupply(), 0);
//         testCommon.deposit(depositAmount, false, true, LLAMALEND_VAULT_CRVUSD);
//         uint256 depositedAmount = testCommon.curveLendVault().convertToAssets(depositAmount);
//         assertEq(testCommon.gUSDImplem().balanceOf(user), depositedAmount);

//         assertEq(testCommon.splitter().gUSDSdtPerLlamaVault(LLAMALEND_VAULT_CRVUSD).totalSupply(), depositedAmount);
//     }

//     function test_deposit_LendcurveassetWithGovRewardDepositDisabled() external {
//         uint256 depositAmount = 100 ether;
//         address user = testCommon.getUser(1, LLAMALEND_VAULT_CRVUSD);

//         assertEq(testCommon.gUSDImplem().balanceOf(user), 0);
//         assertEq(testCommon.splitter().gUSDSdtPerLlamaVault(LLAMALEND_VAULT_CRVUSD).totalSupply(), 0);

//         testCommon.deposit(depositAmount, false, false, LLAMALEND_VAULT_CRVUSD);

//         uint256 depositedAmount = testCommon.curveLendVault().convertToAssets(depositAmount);

//         uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();
//         incentive = testCommon.curveLendVault().convertToAssets(incentive);

//         assertGt(incentive, 0);

//         assertApproxEqAbs(testCommon.gUSDImplem().balanceOf(user), depositedAmount - incentive, 1 wei);

//         assertApproxEqAbs(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), depositedAmount - incentive, 1 wei);
//     }

//     function test_deposit_LendstakeassetWithGovRewardDepositEnabled() external {
//         uint256 depositAmount = 100 ether;
//         address user = testCommon.getUser(1, tokenIn);
//         assertEq(testCommon.gUSDImplem().balanceOf(user), 0);
//         assertEq(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), 0);
//         testCommon.deposit(depositAmount, false, false, address(tokenIn));
//         uint256 depositedAmount = testCommon.curveLendVault().convertToAssets(depositAmount);
//         assertEq(testCommon.gUSDImplem().balanceOf(user), depositedAmount);

//         assertEq(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), depositedAmount);
//     }

//     function test_deposit_LendstakeassetWithGovRewardDepositDisabled() external {
//         uint256 depositAmount = 100 ether;
//         IStakeDaoVault tokenIn = AddrSdtVaults.CRVUSD_CRV;
//         address user = testCommon.getUser(1, address(tokenIn));
//         assertEq(testCommon.gUSDImplem().balanceOf(user), 0);
//         assertEq(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), 0);
//         testCommon.deposit(depositAmount, false, false, address(tokenIn));
//         uint256 depositedAmount = testCommon.curveLendVault().convertToAssets(depositAmount);

//         uint256 incentive = testCommon.stakeDaoVault().incentiveTokenAmount();
//         incentive = testCommon.curveLendVault().convertToAssets(incentive);

//         assertEq(incentive, 0);
//         assertApproxEqAbs(testCommon.gUSDImplem().balanceOf(user), depositedAmount, 1 wei);

//         assertApproxEqAbs(testCommon.splitter().gUSDSdtPerLlamaVault(AddrLlamaLendVaults.CRVUSD_CRV).totalSupply(), depositedAmount, 1 wei);
//     }
// }
