// import {Test, console} from "forge-std/Test.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {DeployContext} from "../DeployContext.sol";
// import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
// import {SplitterToken} from "../../src/tokens/SplitterToken.sol";
// import {scvUSDSdt} from "../../src/tokens/stakeDao/scvUSDSdt.sol";
// import {gUSDSdt} from "../../src/tokens/stakeDao/gUSDSdt.sol";
// import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20, AddrCvxRewardTokens, PidCvxBooster, AddrCvxVaultTokens} from "../../src/libs/Resources.sol";
// import {ILlamaVault} from "../../src/interfaces/externals/LlamaLend/ILlamaVault.sol";
// import {IStakeDaoVault} from "../../src/interfaces/externals/StakeDao/IStakeDaoVault.sol";
// import {ISdtLiquidityGauge} from "../../src/interfaces/externals/StakeDao/ISdtLiquidityGauge.sol";
// import {ICommonStruct} from "../../src/interfaces/internals/ICommonStruct.sol";

// contract LendRewardSplitterStableClaimTest is Test {
//     LendRewardSplitter splitter;
//     DeployContext testCommon;

//     ILlamaVault constant LLAMALEND_VAULT_CRV = AddrLlamaLendVaults.CRVUSD_CRV;
//     IStakeDaoVault constant STAKE_DAO_VAULT_CRV = AddrSdtVaults.CRVUSD_CRV;
//     ISdtLiquidityGauge constant STAKE_DAO_GAUGE_CRV = AddrSdtGauges.CRVUSD_CRV;
//     IERC20 constant CRVUSD = IERC20(AddrClassicERC20.TOKEN_CRVUSD);
//     scvUSDSdt public scvUSD;
//     gUSDSdt public gUSD;
//     uint256 processorFeesPerc;
//     uint256 daoFeesPerc;
//     uint256 denom;

//     address user3 = makeAddr("User3");

//     function setUp() public {
//         testCommon = new DeployContext();
//         testCommon.fork();
//         testCommon.setUpSplitter();
//         splitter = testCommon.splitter();

//         scvUSD = scvUSDSdt(address(splitter.scvUSDSdtPerLlamaVault(LLAMALEND_VAULT_CRV)));
//         gUSD = gUSDSdt(address(splitter.gUSDSdtPerLlamaVault(LLAMALEND_VAULT_CRV)));

//         (processorFeesPerc, daoFeesPerc) = scvUSD.fees(0);
//         denom = scvUSD.DENOMINATOR();
//     }

//     function test_claimStableRewards_nominal() external {
//         // Do the deposit.
//         (address user1, address user2) = deposit();

//         assertEq(CRVUSD.balanceOf(address(splitter)), 0, "No lend asset should be available on splitter");

//         //let the PPS evolve.
//         skip(182 days);

//         // Process the stable rewards.

//         uint256 rewardToProcess = LLAMALEND_VAULT_CRV.convertToAssets(
//             STAKE_DAO_GAUGE_CRV.balanceOf(address(gUSD)) - scvUSD.totalSupply() - LLAMALEND_VAULT_CRV.convertToShares(gUSD.totalSupply())
//         );
//         uint256 processorFees = (rewardToProcess * processorFeesPerc) / denom;
//         uint256 daoFees = (rewardToProcess * daoFeesPerc) / denom;

//         uint256 rewardForStakers = rewardToProcess - processorFees - daoFees;

//         vm.prank(user3);
//         scvUSD.processRewards();

//         assertEq(CRVUSD.balanceOf(user3), processorFees, "Processor fee is not right");
//         assertEq(splitter.daoFeeForToken(CRVUSD), daoFees, "DAO fee is not right");

//         // No time have passed , so no reward sould be available for user, but asset should be on the splitter contract.
//         assertEq(scvUSD.rewardPerToken(CRVUSD), 0, "No reward should be streamed");
//         assertEq(CRVUSD.balanceOf(address(splitter)), rewardToProcess - processorFees, "Lend asset should be available on scvUSD contract");

//         // TODO add 3.5 jours and test claim
//         // Go at the end of the reward period.
//         skip(9 days);

//         // check th claimable rewards
//         ICommonStruct.TokenAmount[] memory userRewards1 = scvUSD.claimableRewards(user1);
//         assertEq(userRewards1.length, 1, "User1 should have 1 reward");
//         assertEq(address(userRewards1[0].token), address(CRVUSD), "Reward token  should be the lend asset");
//         assertApproxEqAbs(userRewards1[0].amount, rewardForStakers, 1e8, "User1 should get almost all the rewards");

//         ICommonStruct.TokenAmount[] memory userRewards2 = scvUSD.claimableRewards(user2);
//         assertEq(userRewards2[0].amount, 0, "User2 should not have rewards ");

//         uint256 balanceUserCrvUsd = CRVUSD.balanceOf(user1);
//         // Claim
//         vm.prank(user1);
//         splitter.claimSimple(address(scvUSD), user1);
//         assertEq(userRewards1[0].amount, CRVUSD.balanceOf(user1) - balanceUserCrvUsd, "User1 should receive all crvUSD claimable");

//         // Retrieve DAO fees

//         address owner = splitter.owner();
//         uint256 balanceOwnerBefore = CRVUSD.balanceOf(owner);
//         IERC20[] memory array = new IERC20[](1);
//         array[0] = CRVUSD;

//         vm.prank(owner);
//         splitter.withdrawFees(array);

//         assertEq(daoFees, CRVUSD.balanceOf(owner) - balanceOwnerBefore, "Owner should receive the fees in crvUSD");
//     }

//     function test_revertWhen_getRewardCalledOnNToken() external {
//         // Do the deposit.
//         (address user1, address user2) = deposit();

//         vm.prank(user1);
//         vm.expectRevert(abi.encodeWithSelector(SplitterToken.NotLendRewardSplitter.selector, user1));
//         scvUSD.getAndUpdateRewards(user1);
//     }

//     function deposit() internal returns (address user1, address user2) {
//         uint256 depositAmount = 10_000 ether;

//         user1 = testCommon.getUser(1, AddrClassicERC20.TOKEN_CRVUSD, depositAmount);
//         testCommon.deposit(depositAmount, true, true, AddrClassicERC20.TOKEN_CRVUSD);
//         vm.stopPrank();
//         user2 = testCommon.getUser(2, AddrClassicERC20.TOKEN_CRVUSD, depositAmount);
//         testCommon.deposit(depositAmount, false, true, AddrClassicERC20.TOKEN_CRVUSD);
//         vm.stopPrank();
//     }
// }
