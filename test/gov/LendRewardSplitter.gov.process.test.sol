// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CurveLendSplitterTokenStream} from "../../src/tokens/CurveLendSplitterTokenStream.sol";
import {IStakeDaoVault} from "../../src/interfaces/IStakeDaoVault.sol";
import {ICurveLendVault} from "../../src/interfaces/ICurveLendVault.sol";
import {Addresses} from "../../src/libs/Addresses.sol";
import {ISDLiquidityGauge} from "../../src/interfaces/ISDLiquidityGauge.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {LendRewardSplitterTestCommon} from "../LendRewardSplitter.common.test.sol";

contract LendRewardSplitterGovProcessTest is Test {
    uint256 constant MAX_UINT = uint256(int256(-1));
    uint256 constant DENOMINATOR = 100_000;

    LendRewardSplitterTestCommon testCommon = new LendRewardSplitterTestCommon();

    IStakeDaoVault stakeDaoVault = IStakeDaoVault(Addresses.STAKEDAO_CRV_VAULT);
    LendRewardSplitter splitter;
    CurveLendSplitterTokenStream scvUSD;
    CurveLendSplitterTokenStream gUSD;
    ISDLiquidityGauge liquidityGauge;
    ICurveLendVault curveLendVault;
    uint256 processorRewardsPercentage;
    uint256 daoFeesPercentage;
    bool isStableReward = false;

    address owner = makeAddr("Owner");
    address depositor = makeAddr("Depositor");
    address processor = makeAddr("Processor");

    function setUp() public {
        testCommon = new LendRewardSplitterTestCommon();
        testCommon.fork();
        splitter = testCommon.setUpSplitter();
        //dealing
        vm.deal(owner, 10 ether);

        liquidityGauge = testCommon.liquidityGauge();
        curveLendVault = testCommon.curveLendVault();
        gUSD = testCommon.gUSD();
        scvUSD = testCommon.scvUSD();

        daoFeesPercentage = gUSD.daoFeesPercentage(); //2%
        processorRewardsPercentage = gUSD.processorRewardsPercentage(); //1%

        /// @dev Deposit
        address tokenIn = Addresses.TOKEN_CRVUSD;
        testCommon.getUser(1, tokenIn);
        bool doDeposit = true;
        uint256 depositedAmount = 1000 ether;
        vm.stopPrank();
        vm.deal(depositor, 10 ether);
        deal(Addresses.TOKEN_CRVUSD, depositor, 1000 ether);
        vm.prank(depositor);
        IERC20(Addresses.TOKEN_CRVUSD).approve(address(splitter), MAX_UINT);
        vm.prank(depositor);
        splitter.deposit(
            address(stakeDaoVault),
            LendRewardSplitter.TOKEN_TYPE.LendAsset,
            depositedAmount,
            isStableReward,
            doDeposit
        );
        vm.stopPrank();
        skip(3600);
        testCommon._takesGaugeOnwershipAndSetDistributor();
    }

    function test_FailProcessGovRewardsWithNothingToClaim() external {
        vm.expectRevert(bytes("NOTHING_TO_PROCESS"));
        gUSD.processGovRewards();
    }

    function test_ProcessGovRewards() external {
        IERC20[] memory rewardTokens = gUSD.getRewardTokens();
        assertEq(rewardTokens.length, 0);
        _processGovReward(false);
        /// @dev Check if rewards tokens have been added correctly
        rewardTokens = gUSD.getRewardTokens();
        assertEq(address(rewardTokens[0]), Addresses.TOKEN_SDT);
        assertEq(address(rewardTokens[1]), Addresses.TOKEN_CRV);
        assertEq(address(rewardTokens[2]), Addresses.TOKEN_CVX);
        assertEq(address(rewardTokens[3]), Addresses.TOKEN_CRVUSD);
        //CRV
        IERC20 CRV = IERC20(Addresses.TOKEN_CRV);
        assertEq(crvClaimable, CRV.balanceOf(address(splitter)) - crvDaoFees);
        assertEq(crvProcessorRewards, CRV.balanceOf(address(processor)));
        assertEq(crvDaoFees, CRV.balanceOf(address(splitter)) - crvClaimable);
        assertEq(crvDaoFees, splitter.daoFeeForToken(CRV));
        //SDT
        IERC20 SDT = IERC20(Addresses.TOKEN_SDT);
        assertEq(sdtClaimable, SDT.balanceOf(address(splitter)) - sdtDaoFees);
        assertEq(sdtProcessorRewards, SDT.balanceOf(address(processor)));
        assertEq(sdtDaoFees, SDT.balanceOf(address(splitter)) - sdtClaimable);
        assertEq(sdtDaoFees, splitter.daoFeeForToken(SDT));
    }
    function test_processGovRewardWithRewardClaimedByUser() external {
        _processGovReward(true);

        //CRV
        IERC20 CRV = IERC20(Addresses.TOKEN_CRV);
        assertEq(crvClaimable + crvDaoFees, CRV.balanceOf(address(splitter)));
        assertEq(crvProcessorRewards, CRV.balanceOf(address(processor)));
        assertEq(crvDaoFees, CRV.balanceOf(address(splitter)) - crvClaimable);
        assertEq(crvDaoFees, splitter.daoFeeForToken(CRV));
        //SDT
        IERC20 SDT = IERC20(Addresses.TOKEN_SDT);
        assertEq(sdtClaimable + sdtDaoFees, SDT.balanceOf(address(splitter)));
        assertEq(sdtProcessorRewards, SDT.balanceOf(address(processor)));
        assertEq(sdtDaoFees, SDT.balanceOf(address(splitter)) - sdtClaimable);
        assertEq(sdtDaoFees, splitter.daoFeeForToken(SDT));
    }

    function test_processGovRewardsAndClaimFees() external {
        _processGovReward(false);
        /// @dev claim fees
        vm.prank(owner);
        IERC20 CRV = IERC20(Addresses.TOKEN_CRV);
        IERC20 SDT = IERC20(Addresses.TOKEN_SDT);
        IERC20[] memory tokensToClaim = new IERC20[](2);
        tokensToClaim[0] = CRV;
        tokensToClaim[1] = SDT;
        splitter.withdrawFees(tokensToClaim);
        //CRV
        assertEq(0, CRV.balanceOf(address(splitter)) - crvClaimable);
        assertEq(crvDaoFees, CRV.balanceOf(address(owner)));
        assertEq(0, splitter.daoFeeForToken(CRV));
        //SDT
        assertEq(0, SDT.balanceOf(address(splitter)) - sdtClaimable);
        assertEq(sdtDaoFees, SDT.balanceOf(address(owner)));
        assertEq(0, splitter.daoFeeForToken(SDT));
    }

    function test_processGovRewardTwice() external {
        /// @dev First Process
        _processGovReward(false);
        uint256 crvClaimableOne = crvClaimable;
        uint256 crvProcessorRewardsOne = crvProcessorRewards;
        uint256 crvDaoFeesOne = crvDaoFees;
        uint256 sdtClaimableOne = sdtClaimable;
        uint256 sdtProcessorRewardsOne = sdtProcessorRewards;
        uint256 sdtDaoFeesOne = sdtDaoFees;
        /// @dev Second Process
        _processGovReward(false);
        //CRV
        IERC20 CRV = IERC20(Addresses.TOKEN_CRV);
        assertEq(crvClaimableOne + crvClaimable + crvDaoFeesOne + crvDaoFees, CRV.balanceOf(address(splitter)));
        assertEq(crvProcessorRewardsOne + crvProcessorRewards, CRV.balanceOf(address(processor)));
        assertEq(crvDaoFeesOne + crvDaoFees, (CRV.balanceOf(address(splitter)) - crvClaimableOne - crvClaimable));
        assertEq(crvDaoFeesOne + crvDaoFees, splitter.daoFeeForToken(CRV));
        //SDT
        IERC20 SDT = IERC20(Addresses.TOKEN_SDT);
        assertEq(sdtClaimableOne + sdtClaimable + sdtDaoFeesOne + sdtDaoFees, SDT.balanceOf(address(splitter)));
        assertEq(sdtProcessorRewardsOne + sdtProcessorRewards, SDT.balanceOf(address(processor)));
        assertEq(sdtDaoFeesOne + sdtDaoFees, SDT.balanceOf(address(splitter)) - sdtClaimableOne - sdtClaimable);
        assertEq(sdtDaoFeesOne + sdtDaoFees, splitter.daoFeeForToken(SDT));
    }

    function test_processGovRewardTwiceAndClaimFees() external {
        /// @dev First Process
        _processGovReward(false);
        uint256 crvClaimableOne = crvClaimable;
        uint256 crvProcessorRewardsOne = crvProcessorRewards;
        uint256 crvDaoFeesOne = crvDaoFees;
        uint256 sdtClaimableOne = sdtClaimable;
        uint256 sdtProcessorRewardsOne = sdtProcessorRewards;
        uint256 sdtDaoFeesOne = sdtDaoFees;
        /// @dev Second Process
        _processGovReward(false);

        /// @dev claim fees
        vm.prank(owner);
        IERC20 CRV = IERC20(Addresses.TOKEN_CRV);
        IERC20 SDT = IERC20(Addresses.TOKEN_SDT);
        IERC20[] memory tokensToClaim = new IERC20[](2);
        tokensToClaim[0] = CRV;
        tokensToClaim[1] = SDT;
        splitter.withdrawFees(tokensToClaim);
        //CRV
        assertEq(0, CRV.balanceOf(address(splitter)) - crvClaimableOne - crvClaimable);
        assertEq(crvDaoFeesOne + crvDaoFees, CRV.balanceOf(address(owner)));
        assertEq(0, splitter.daoFeeForToken(CRV));
        //SDT
        assertEq(0, SDT.balanceOf(address(splitter)) - sdtClaimableOne - sdtClaimable);
        assertEq(sdtDaoFeesOne + sdtDaoFees, SDT.balanceOf(address(owner)));
        assertEq(0, splitter.daoFeeForToken(SDT));
    }

    //TODO: owner reverts function

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                       INTERNALS
   =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    uint256 sdtClaimable;
    uint256 sdtProcessorRewards;
    uint256 sdtDaoFees;
    uint256 crvClaimable;
    uint256 crvProcessorRewards;
    uint256 crvDaoFees;
    function _processGovReward(bool isClaimedByUser) internal {
        LendRewardSplitterTestCommon.DistributionGauge[]
            memory distributionGauges = new LendRewardSplitterTestCommon.DistributionGauge[](2);
        distributionGauges[1] = LendRewardSplitterTestCommon.DistributionGauge({
            token: Addresses.TOKEN_CRV,
            amount: 100 ether
        });
        distributionGauges[0] = LendRewardSplitterTestCommon.DistributionGauge({
            token: Addresses.TOKEN_SDT,
            amount: 10 ether
        });
        testCommon._distributeGaugeRewards(distributionGauges);
        skip(72000);
        //CRV
        crvClaimable = liquidityGauge.claimable_reward(address(splitter), Addresses.TOKEN_CRV);
        crvProcessorRewards = (crvClaimable * processorRewardsPercentage) / DENOMINATOR;
        crvDaoFees = (crvClaimable * daoFeesPercentage) / DENOMINATOR;
        crvClaimable -= crvProcessorRewards;
        crvClaimable -= crvDaoFees;
        //SDT
        sdtClaimable = liquidityGauge.claimable_reward(address(splitter), Addresses.TOKEN_SDT);
        sdtProcessorRewards = (sdtClaimable * processorRewardsPercentage) / DENOMINATOR;
        sdtDaoFees = (sdtClaimable * daoFeesPercentage) / DENOMINATOR;
        sdtClaimable -= sdtProcessorRewards;
        sdtClaimable -= sdtDaoFees;

        /// @dev claim rewards with a random user outside of the process
        if (isClaimedByUser) liquidityGauge.claim_rewards(address(splitter));

        vm.prank(processor);
        gUSD.processGovRewards();
    }
}
