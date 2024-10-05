// import {Test, console} from "forge-std/Test.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {DeployContext} from "../DeployContext.sol";
// import {scvUSDSdt} from "../../src/tokens/stakeDao/scvUSDSdt.sol";
// import {gUSDSdt} from "../../src/tokens/stakeDao/gUSDSdt.sol";
// import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
// import {SplitterToken} from "../../src/tokens/SplitterToken.sol";
// import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20} from "../../src/libs/Resources.sol";
// import {ISdtLiquidityGauge} from "../../src/interfaces/externals/ISdtLiquidityGauge.sol";
// import {ILlamaVault} from "../../src/interfaces/externals/ILlamaVault.sol";
// import {IStakeDaoVault} from "../../src/interfaces/externals/IStakeDaoVault.sol";

// contract LendRewardSplitterStableProcessTest is Test {
//     LendRewardSplitter splitter;
//     DeployContext testCommon;

//     ILlamaVault constant LLAMALEND_VAULT_CRV = AddrLlamaLendVaults.CRVUSD_CRV;
//     IStakeDaoVault constant STAKE_DAO_VAULT_CRV = AddrSdtVaults.CRVUSD_CRV;
//     ISdtLiquidityGauge constant STAKE_DAO_GAUGE_CRV = AddrSdtGauges.CRVUSD_CRV;
//     IERC20 constant CRVUSD = IERC20(AddrClassicERC20.TOKEN_CRVUSD);
//     scvUSDSdt public scvUSD;
//     gUSDSdt public gUSD;

//     function setUp() public {
//         testCommon = new DeployContext();
//         testCommon.fork();
//         testCommon.setUpSplitter();
//         splitter = testCommon.splitter();

//         scvUSD = scvUSDSdt(address(splitter.scvUSDSdtPerLlamaVault(LLAMALEND_VAULT_CRV)));
//         gUSD = gUSDSdt(address(splitter.gUSDSdtPerLlamaVault(LLAMALEND_VAULT_CRV)));
//     }

//     // function test_revertWhen_processStableRewards_with_no_reward() external {
//     //     address user3 = makeAddr("user processor");
//     //     deal(user3, 100 ether);
//     //     assertEq(CRVUSD.balanceOf(user3), 0);

//     //     vm.startPrank(user3);
//     //     vm.expectRevert(abi.encodeWithSelector(SplitterToken.NothingToProcess.selector));
//     //     scvUSD.processRewards();
//     //     vm.stopPrank();
//     // }

//     function test_processStableRewards_nominal() external {
//         // DO the deposit.
//         uint256 depositAmount = 10_000 ether;
//         address tokenIn = address(LLAMALEND_VAULT_CRV);
//         // Create user and prank
//         testCommon.getUser(1, tokenIn, depositAmount);
//         testCommon.deposit(depositAmount, true, true, tokenIn);
//         vm.stopPrank();

//         // Create user and prank
//         testCommon.getUser(2, tokenIn, depositAmount);
//         testCommon.deposit(depositAmount, false, true, tokenIn);
//         vm.stopPrank();

//         //let the PPS evolve.
//         skip(30 days);
//         // Prepare the processor user.
//         address user3 = makeAddr("user processor");
//         deal(user3, 100 ether);
//         assertEq(CRVUSD.balanceOf(user3), 0);

//         // Get all info .
//         (, uint256 stableReward, uint256 expectedProcessorFees, uint256 expectedDaoFees) = _getStableRewardToProcess(LLAMALEND_VAULT_CRV);

//         // Process the stable Rewards.
//         vm.startPrank(user3);
//         scvUSD.processRewards();
//         vm.stopPrank();

//         //Check all this.
//         assertEq(CRVUSD.balanceOf(user3), expectedProcessorFees, "Processor Fees Not detected");
//         assertEq(CRVUSD.balanceOf(address(splitter)), stableReward - expectedProcessorFees, "Rewards Not detected");
//         assertEq(splitter.daoFeeForToken(CRVUSD), expectedDaoFees, "DAO Fees Not detected");
//     }

//     function _getStableRewardToProcess(ILlamaVault llamaLendVault) internal view returns (uint256, uint256, uint256, uint256) {
//         // Count the share.
//         uint256 shareReward = splitter.sdtGaugePerLlamaVault(llamaLendVault).balanceOf(address(gUSD)) -
//             scvUSD.totalSupply() -
//             llamaLendVault.convertToShares(gUSD.totalSupply());

//         // Emulate the withdraw.
//         uint256 stableReward = llamaLendVault.convertToAssets(shareReward);

//         (uint256 processorFees, uint256 daoFees) = scvUSD.fees(0);

//         // And calculation.

//         uint256 DENOMINATOR = scvUSD.DENOMINATOR();
//         uint256 expectedProcessorFees = (stableReward * processorFees) / DENOMINATOR;
//         uint256 expectedDaoFees = (stableReward * daoFees) / DENOMINATOR;
//         return (shareReward, stableReward, expectedProcessorFees, expectedDaoFees);
//     }
// }
