// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import {Test, console} from "forge-std/Test.sol";
// import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
// import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
// import {CurveLendSplitterToken} from "../../src/tokens/CurveLendSplitterToken.sol";
// import {gUSDSdt} from "../../src/tokens/stakeDao/gUSDSdt.sol";
// import {scvUSDSdt} from "../../src/tokens/stakeDao/scvUSDSdt.sol";
// import {AddrLlamaLendVaults, AddrSdtVaults, AddrSdtGauges, AddrClassicERC20} from "../../src/libs/Resources.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {IStakeDaoVault} from "../../src/interfaces/externals/IStakeDaoVault.sol";
// import {ILlamaLendVault} from "../../src/interfaces/externals/ILlamaLendVault.sol";
// import {ISdtLiquidityGauge} from "../../src/interfaces/externals/ISdtLiquidityGauge.sol";
// import {ILendRewardSplitter} from "../../src/interfaces/internals/ILendRewardSplitter.sol";
// import {ICurveLendSplitterToken} from "../../src/interfaces/internals/ICurveLendSplitterToken.sol";
// import {DeployContext} from "../DeployContext.sol";
// import {ICommonStruct} from "../../src/interfaces/internals/ICommonStruct.sol";

// contract ProcessGovRewardsSdt is Test {
//     uint256 constant MAX_UINT = uint256(int256(-1));
//     uint256 constant DENOMINATOR = 100_000;

//     DeployContext testCommon = new DeployContext();

//     IStakeDaoVault stakeDaoVault = IStakeDaoVault(AddrSdtVaults.CRVUSD_CRV);
//     LendRewardSplitter splitter;
//     scvUSDSdt scvUSDImplem;
//     gUSDSdt gUSDImplem;
//     ISdtLiquidityGauge liquidityGauge;
//     ILlamaLendVault curveLendVault;

//     uint256 processorFeePercentageCrv;
//     uint256 daoFeePercentageCrv;

//     uint256 processorFeePercentageCvx;
//     uint256 daoFeePercentageCvx;

//     bool isStableReward = false;

//     address owner = makeAddr("Owner");
//     address depositor = makeAddr("Depositor");
//     address processor = makeAddr("Processor");

//     IERC20 constant CRV = IERC20(AddrClassicERC20.TOKEN_CRV);
//     IERC20 constant CVX = IERC20(AddrClassicERC20.TOKEN_CVX);

//     function setUp() public {
//         testCommon = new DeployContext();
//         testCommon.fork();
//         testCommon.setUpSplitter();
//         //dealing
//         vm.deal(owner, 10 ether);

//         splitter = testCommon.splitter();
//         liquidityGauge = testCommon.liquidityGauge();
//         curveLendVault = testCommon.curveLendVault();
//         gUSDImplem = testCommon.gUSDImplem();
//         scvUSDImplem = testCommon.scvUSDImplem();

//         (processorFeePercentageCrv, daoFeePercentageCrv) = gUSDImplem.fees(0); //1%

//         (processorFeePercentageCvx, daoFeePercentageCvx) = gUSDImplem.fees(1); //1%

//         /// @dev Deposit
//         testCommon.getUser(1, AddrClassicERC20.TOKEN_CRVUSD);
//         bool doDeposit = true;
//         uint256 depositedAmount = 1000 ether;
//         vm.stopPrank();
//         vm.deal(depositor, 10 ether);
//         deal(address(AddrClassicERC20.TOKEN_CRVUSD), depositor, 1000 ether);
//         vm.startPrank(depositor);
//         IERC20(AddrClassicERC20.TOKEN_CRVUSD).approve(address(splitter), MAX_UINT);
//         splitter.depositSdt(AddrLlamaLendVaults.CRVUSD_CRV, ILendRewardSplitter.SDT_TOKEN_TYPE.LendAsset, depositedAmount, isStableReward, doDeposit);

//         vm.stopPrank();
//         skip(3600);
//         testCommon._takesGaugeOnwershipAndSetDistributor(AddrSdtGauges.CRVUSD_CRV);
//     }

//     function test_FailProcessGovRewardsWithNothingToClaim() external {
//         vm.expectRevert(abi.encodeWithSelector(CurveLendSplitterToken.NothingToProcess.selector));
//         gUSDImplem.processRewards();
//     }

//     function test_ProcessGovRewards() external {
//         IERC20[] memory rewardTokens = gUSDImplem.getRewardTokens();
//         assertEq(rewardTokens.length, 2);
//         _processGovReward(false);

//         assertEq(address(rewardTokens[0]), address(AddrClassicERC20.TOKEN_CRV));
//         assertEq(address(rewardTokens[1]), address(AddrClassicERC20.TOKEN_CVX));

//         //CRV
//         assertEq(crvClaimable, CRV.balanceOf(address(splitter)) - crvDaoFees);
//         assertEq(crvProcessorRewards, CRV.balanceOf(address(processor)));
//         assertEq(crvDaoFees, CRV.balanceOf(address(splitter)) - crvClaimable);
//         assertEq(crvDaoFees, splitter.daoFeeForToken(CRV));

//         //CRV
//         assertEq(cvxClaimable, CVX.balanceOf(address(splitter)) - cvxDaoFees);
//         assertEq(cvxProcessorRewards, CVX.balanceOf(address(processor)));
//         assertEq(cvxDaoFees, CVX.balanceOf(address(splitter)) - cvxClaimable);
//         assertEq(cvxDaoFees, splitter.daoFeeForToken(CVX));
//     }

//     function test_processGovRewardWithRewardClaimedByUser() external {
//         _processGovReward(true);

//         //CRV
//         assertEq(crvClaimable + crvDaoFees, CRV.balanceOf(address(splitter)));
//         assertEq(crvProcessorRewards, CRV.balanceOf(address(processor)));
//         assertEq(crvDaoFees, CRV.balanceOf(address(splitter)) - crvClaimable);
//         assertEq(crvDaoFees, splitter.daoFeeForToken(CRV));
//         //CVX
//         assertEq(cvxClaimable + cvxDaoFees, CVX.balanceOf(address(splitter)));
//         assertEq(cvxProcessorRewards, CVX.balanceOf(address(processor)));
//         assertEq(cvxDaoFees, CVX.balanceOf(address(splitter)) - cvxClaimable);
//         assertEq(cvxDaoFees, splitter.daoFeeForToken(CVX));
//     }

//     function test_processGovRewardsAndClaimFees() external {
//         _processGovReward(false);
//         /// @dev claim fees
//         vm.prank(owner);
//         IERC20[] memory tokensToClaim = new IERC20[](2);
//         tokensToClaim[0] = CRV;
//         tokensToClaim[1] = CVX;
//         splitter.withdrawFees(tokensToClaim);
//         //CRV
//         assertEq(0, CRV.balanceOf(address(splitter)) - crvClaimable);
//         assertEq(crvDaoFees, CRV.balanceOf(address(owner)));
//         assertEq(0, splitter.daoFeeForToken(CRV));

//         //CVX
//         assertEq(0, CVX.balanceOf(address(splitter)) - cvxClaimable);
//         assertEq(cvxDaoFees, CVX.balanceOf(address(owner)));
//         assertEq(0, splitter.daoFeeForToken(CVX));
//     }

//     function test_processGovRewardTwice() external {
//         /// @dev First Process
//         _processGovReward(false);
//         uint256 crvClaimableOne = crvClaimable;
//         uint256 crvProcessorRewardsOne = crvProcessorRewards;
//         uint256 crvDaoFeesOne = crvDaoFees;
//         uint256 sdtClaimableOne = cvxClaimable;
//         uint256 sdtProcessorRewardsOne = cvxProcessorRewards;
//         uint256 sdtDaoFeesOne = cvxDaoFees;
//         /// @dev Second Process
//         _processGovReward(false);
//         //CRV
//         assertEq(crvClaimableOne + crvClaimable + crvDaoFeesOne + crvDaoFees, CRV.balanceOf(address(splitter)));
//         assertEq(crvProcessorRewardsOne + crvProcessorRewards, CRV.balanceOf(address(processor)));
//         assertEq(crvDaoFeesOne + crvDaoFees, (CRV.balanceOf(address(splitter)) - crvClaimableOne - crvClaimable));
//         assertEq(crvDaoFeesOne + crvDaoFees, splitter.daoFeeForToken(CRV));
//         //CVX
//         assertEq(sdtClaimableOne + cvxClaimable + sdtDaoFeesOne + cvxDaoFees, CVX.balanceOf(address(splitter)));
//         assertEq(sdtProcessorRewardsOne + cvxProcessorRewards, CVX.balanceOf(address(processor)));
//         assertEq(sdtDaoFeesOne + cvxDaoFees, CVX.balanceOf(address(splitter)) - sdtClaimableOne - cvxClaimable);
//         assertEq(sdtDaoFeesOne + cvxDaoFees, splitter.daoFeeForToken(CVX));
//     }

//     function test_processGovRewardTwiceAndClaimFees() external {
//         /// @dev First Process
//         _processGovReward(false);
//         uint256 crvClaimableOne = crvClaimable;
//         uint256 crvDaoFeesOne = crvDaoFees;
//         uint256 sdtClaimableOne = cvxClaimable;
//         uint256 sdtDaoFeesOne = cvxDaoFees;
//         /// @dev Second Process
//         _processGovReward(false);

//         /// @dev claim fees
//         vm.prank(owner);
//         IERC20[] memory tokensToClaim = new IERC20[](2);
//         tokensToClaim[0] = CRV;
//         tokensToClaim[1] = CVX;
//         splitter.withdrawFees(tokensToClaim);
//         //CRV
//         assertEq(0, CRV.balanceOf(address(splitter)) - crvClaimableOne - crvClaimable);
//         assertEq(crvDaoFeesOne + crvDaoFees, CRV.balanceOf(address(owner)));
//         assertEq(0, splitter.daoFeeForToken(CRV));
//         //CVX
//         assertEq(0, CVX.balanceOf(address(splitter)) - sdtClaimableOne - cvxClaimable);
//         assertEq(sdtDaoFeesOne + cvxDaoFees, CVX.balanceOf(address(owner)));
//         assertEq(0, splitter.daoFeeForToken(CVX));
//     }

//     function test_RevertWhen_ClaimFeesWithATokenAsNothingToClaim() external {
//         /// @dev First Process
//         _processGovReward(false);

//         /// @dev claim fees
//         vm.prank(owner);
//         IERC20[] memory tokensToClaim = new IERC20[](3);
//         tokensToClaim[0] = CRV;
//         tokensToClaim[1] = CVX;
//         tokensToClaim[2] = IERC20(AddrClassicERC20.TOKEN_CVX);
//         vm.expectRevert(bytes("SOME_TOKEN_WITHDRAW_0"));
//         splitter.withdrawFees(tokensToClaim);
//     }

//     function test_RevertWhen_updateDaoFeesWithNotUpdater() external {
//         ICommonStruct.TokenAmount[] memory tokenAmounts = new ICommonStruct.TokenAmount[](1);
//         tokenAmounts[0] = ICommonStruct.TokenAmount({token: CRV, amount: 5});
//         vm.expectRevert(abi.encodeWithSignature("CallerNotLendSplitterToken()"));
//         splitter.incrementDaoFees(tokenAmounts);
//     }

//     function test_RevertWhen_withdrawFeesNotOwner() external {
//         IERC20[] memory tokensToClaim = new IERC20[](2);
//         tokensToClaim[0] = CRV;
//         tokensToClaim[1] = CVX;
//         vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", depositor));
//         vm.prank(depositor);
//         splitter.withdrawFees(tokensToClaim);
//     }

//     /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
//                            INTERNALS
//        =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
//     uint256 cvxClaimable;
//     uint256 cvxProcessorRewards;
//     uint256 cvxDaoFees;
//     uint256 crvClaimable;
//     uint256 crvProcessorRewards;
//     uint256 crvDaoFees;

//     function _processGovReward(bool isClaimedByUser) internal {
//         ICommonStruct.TokenAmount[] memory distributionGauges = new ICommonStruct.TokenAmount[](2);
//         distributionGauges[0] = ICommonStruct.TokenAmount({token: IERC20(AddrClassicERC20.TOKEN_CRV), amount: 100 ether});
//         distributionGauges[1] = ICommonStruct.TokenAmount({token: IERC20(AddrClassicERC20.TOKEN_CVX), amount: 10 ether});
//         testCommon._distributeGaugeRewards(ISdtLiquidityGauge(stakeDaoVault.liquidityGauge()), distributionGauges);
//         skip(72000);
//         //CRV
//         crvClaimable = liquidityGauge.claimable_reward(address(gUSDImplem), address(AddrClassicERC20.TOKEN_CRV));
//         crvProcessorRewards = (crvClaimable * processorFeePercentageCrv) / DENOMINATOR;
//         crvDaoFees = (crvClaimable * daoFeePercentageCrv) / DENOMINATOR;
//         crvClaimable -= crvProcessorRewards;
//         crvClaimable -= crvDaoFees;
//         //CVX
//         cvxClaimable = liquidityGauge.claimable_reward(address(gUSDImplem), address(AddrClassicERC20.TOKEN_CVX));
//         cvxProcessorRewards = (cvxClaimable * processorFeePercentageCvx) / DENOMINATOR;
//         cvxDaoFees = (cvxClaimable * daoFeePercentageCvx) / DENOMINATOR;
//         cvxClaimable -= cvxProcessorRewards;
//         cvxClaimable -= cvxDaoFees;

//         /// @dev claim rewards with a random user outside of the process
//         if (isClaimedByUser) liquidityGauge.claim_rewards(address(gUSDImplem));

//         vm.prank(processor);
//         gUSDImplem.processRewards();
//     }
// }
