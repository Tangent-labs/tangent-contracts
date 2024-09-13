// import {Test, console} from "forge-std/Test.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";
// import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
// import {CurveLendSplitterToken} from "../../src/tokens/CurveLendSplitterToken.sol";
// import {scvUSDSdt} from "../../src/tokens/stakeDao/scvUSDSdt.sol";
// import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20, AddrCvxRewardTokens, PidCvxBooster, AddrCvxVaultTokens} from "../../src/libs/Resources.sol";
// import {ILlamaLendVault} from "../../src/interfaces/externals/ILlamaLendVault.sol";
// import {IStakeDaoVault} from "../../src/interfaces/externals/IStakeDaoVault.sol";
// import {ICommonStruct} from "../../src/interfaces/internals/ICommonStruct.sol";

// contract LendRewardSplitterStableClaimTest is Test {
//     LendRewardSplitter splitter;
//     LendRewardSplitterTestCommon testCommon;

//     ILlamaLendVault constant LLAMALEND_VAULT_CRV = AddrLlamaLendVaults.CRVUSD_CRV;
//     IStakeDaoVault constant STAKE_DAO_VAULT_CRV = AddrSdtVaults.CRVUSD_CRV;
//     address constant CRVUSD = AddrClassicERC20.TOKEN_CRVUSD;
//     scvUSDSdt public scvUSD;

//     function setUp() public {
//         testCommon = new LendRewardSplitterTestCommon();
//         testCommon.fork();
//         testCommon.setUpSplitter();
//         splitter = testCommon.splitter();

//         scvUSD = scvUSDSdt(address(splitter.scvUSDSdtPerLlamaVault(LLAMALEND_VAULT_CRV)));
//     }

//     function test_claimStableRewards_nominal() external {
//         // Do the deposit.
//         (address user1, address user2) = deposit();

//         assertEq(IERC20(CRVUSD).balanceOf(address(splitter)), 0, "No lend asset should be available on splitter");

//         //let the PPS evolve.
//         skip(200 days);

//         // Process the stable rewards.
//         vm.startPrank(user2);
//         uint256 rewardToProcess = scvUSD.processStableRewards(address(STAKE_DAO_VAULT_CRV));
//         vm.stopPrank();

//         // this part is in the balance but not distributed as reward
//         uint256 daoFeesForLendAsset = splitter.daoFeeForToken(CRVUSD);

//         // No time have passed , so no reward sould be available for user , but asset should be on the splitter contract.
//         assertEq(scvUSD.rewardPerToken(CRVUSD), 0, "No reward should be streamed");
//         assertEq(CRVUSD.balanceOf(address(splitter)), rewardToProcess + daoFeesForLendAsset, "Lend asset should be available on splitter contract");

//         // TODO add 3.5 jours and test claim

//         // Go at the end of the reward period.
//         skip(9 days);

//         // check th claimable rewards
//         ICommonStruct.TokenAmount[] memory userRewards1 = scvUSD.claimableRewards(user1);
//         assertEq(userRewards1.length, 1, "User1 should have 1 reward");
//         assertEq(address(userRewards1[0].token), address(CRVUSD), "Reward token  should be the lend asset");
//         // assertEq(userRewards1[0].amount, rewardToProcess, "User1 should  get alll the reward");
//         ICommonStruct.TokenAmount[] memory userRewards2 = scvUSD.claimableRewards(user2);
//         assertEq(userRewards2.length, 1, "User2 should not have rewards ");
//         assertEq(userRewards2[0].amount, 0, "User2 should not have rewards ");

//         //Claim
//         vm.startPrank(user1);
//         splitter.claimSimple(scvUSD, false, user1);

//         vm.stopPrank();
//         uint256 userBalance = CRVUSD.balanceOf(user1);
//         uint256 splitterBalance = CRVUSD.balanceOf(address(splitter));
//         assertEq(userBalance + splitterBalance - daoFeesForLendAsset, rewardToProcess, "Balances must match the reward processed");
//         console.log(userBalance, splitterBalance);
//     }

//     function test_revertWhen_getRewardCalledOnNToken() external {
//         // Do the deposit.
//         (address user1, address user2) = deposit();

//         vm.startPrank(user1);
//         vm.expectRevert("NOT_SPLITTER");
//         scvUSD.getReward(user1);
//         vm.stopPrank();
//     }

//     function deposit() internal returns (address user1, address user2) {
//         uint256 depositAmount = 10_000 ether;
//         address tokenIn = address(AddrLlamaLendVaults.CRVUSD_CRV);
//         user1 = testCommon.getUser(1, tokenIn, depositAmount);
//         testCommon.deposit(depositAmount, true, true, tokenIn);
//         vm.stopPrank();
//         user2 = testCommon.getUser(2, tokenIn, depositAmount);
//         testCommon.deposit(depositAmount, false, true, tokenIn);
//         vm.stopPrank();
//     }
// }
