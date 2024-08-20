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

contract LendRewardSplitterGovProcessTest is Test {
    uint256 constant MAX_UINT = uint256(int256(-1));
    uint256 constant DENOMINATOR = 100_000;

    LendRewardSplitter splitter;
    CurveLendSplitterTokenStream scvUSD;
    CurveLendSplitterTokenStream gUSD;
    IERC20 liquidityGauge;
    ICurveLendVault curveLendVault;
    uint256 processorRewardsPercentage;
    uint256 daoFeesPercentage;
    bool isStableReward = false;

    address owner = makeAddr("Owner");
    address depositor = makeAddr("Depositor");
    address ownerGauge = makeAddr("ownerGauge");
    address processor = makeAddr("Processor");

    function _getUser(uint index, address token) internal returns (address user) {
        user = makeAddr(string.concat("user", vm.toString((index))));
        vm.deal(user, 10 ether);
        if (token == Addresses.STAKEDAO_CRV_VAULT) {
            token = IStakeDaoVault(Addresses.STAKEDAO_CRV_VAULT).liquidityGauge();
        }
        vm.startPrank(user);
        deal(token, user, 1000 ether);
        IERC20(token).approve(address(splitter), MAX_UINT);
    }

    function setUp() public {
        vm.createSelectFork("mainnet", 20513092);
        vm.deal(owner, 10 ether);
        vm.deal(ownerGauge, 10 ether);

        liquidityGauge = IERC20(IStakeDaoVault(Addresses.STAKEDAO_CRV_VAULT).liquidityGauge());
        curveLendVault = ICurveLendVault(Addresses.CURVE_CRV_VAULT);

        scvUSD = new CurveLendSplitterTokenStream();
        scvUSD.initialize("Stable USD/CRV", "scvUSD-CRV");
        gUSD = new CurveLendSplitterTokenStream();
        gUSD.initialize("Governance USD/CRV", "gUSD-CRV");

        splitter = new LendRewardSplitter();

        scvUSD.setLendRewardSplitter(address(splitter));
        gUSD.setLendRewardSplitter(address(splitter));
        //labelizing
        vm.label(Addresses.TOKEN_CRVUSD, "crvUSD");
        vm.label(Addresses.STAKEDAO_CRV_VAULT, "STAKEDAO_CRV_VAULT");
        vm.label(Addresses.CURVE_CRV_VAULT, "CURVE_CRV_VAULT");
        vm.label(IStakeDaoVault(Addresses.STAKEDAO_CRV_VAULT).strategy(), "STAKEDAO_CRV_STRATEGY");
        vm.label(IStakeDaoVault(Addresses.STAKEDAO_CRV_VAULT).liquidityGauge(), "STAKEDAO_CRV_LIQUIDITY_GAUGE");
        /*
            address _curveLendVault,
            address _stakeDaoVault,
            address _curveGauge
        */
        vm.prank(owner);
        splitter.initialize(Addresses.CURVE_CRV_VAULT, Addresses.STAKEDAO_CRV_VAULT, address(gUSD), address(scvUSD));

        daoFeesPercentage = gUSD.daoFeesPercentage(); //2%
        processorRewardsPercentage = gUSD.processorRewardsPercentage(); //1%

        /// @dev Deposit
        address tokenIn = Addresses.TOKEN_CRVUSD;
        _getUser(1, tokenIn);
        bool doDeposit = true;
        uint256 depositedAmount = 1000 ether;
        vm.stopPrank();
        vm.deal(depositor, 10 ether);
        deal(Addresses.TOKEN_CRVUSD, depositor, 1000 ether);
        vm.prank(depositor);
        IERC20(Addresses.TOKEN_CRVUSD).approve(address(splitter), MAX_UINT);
        vm.prank(depositor);
        splitter.deposit(LendRewardSplitter.TOKEN_TYPE.LendAsset, depositedAmount, isStableReward, doDeposit);
        vm.stopPrank();
        skip(3600);
        _takesGaugeOnwershipAndSetDistributor();
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
        ISDLiquidityGauge _liquidityGauge = ISDLiquidityGauge(address(liquidityGauge));
        DistributionGauge[] memory distributionGauges = new DistributionGauge[](2);
        distributionGauges[1] = DistributionGauge({token: Addresses.TOKEN_CRV, amount: 100 ether});
        distributionGauges[0] = DistributionGauge({token: Addresses.TOKEN_SDT, amount: 10 ether});
        _distributeGaugeRewards(distributionGauges);
        skip(72000);
        //CRV
        crvClaimable = _liquidityGauge.claimable_reward(address(splitter), Addresses.TOKEN_CRV);
        crvProcessorRewards = (crvClaimable * processorRewardsPercentage) / DENOMINATOR;
        crvDaoFees = (crvClaimable * daoFeesPercentage) / DENOMINATOR;
        crvClaimable -= crvProcessorRewards;
        crvClaimable -= crvDaoFees;
        //SDT
        sdtClaimable = _liquidityGauge.claimable_reward(address(splitter), Addresses.TOKEN_SDT);
        sdtProcessorRewards = (sdtClaimable * processorRewardsPercentage) / DENOMINATOR;
        sdtDaoFees = (sdtClaimable * daoFeesPercentage) / DENOMINATOR;
        sdtClaimable -= sdtProcessorRewards;
        sdtClaimable -= sdtDaoFees;

        /// @dev claim rewards with a random user outside of the process
        if (isClaimedByUser) _liquidityGauge.claim_rewards(address(splitter));

        vm.prank(processor);
        gUSD.processGovRewards();
    }

    function _takesGaugeOnwershipAndSetDistributor() internal {
        ISDLiquidityGauge _liquidityGauge = ISDLiquidityGauge(address(liquidityGauge));
        address admin = _liquidityGauge.admin();
        uint256 rewardCount = _liquidityGauge.reward_count();
        for (uint256 i; i < rewardCount; ) {
            IERC20 token = IERC20(_liquidityGauge.reward_tokens(i));
            vm.prank(ownerGauge);
            token.approve(address(liquidityGauge), 0);
            vm.prank(ownerGauge);
            token.approve(address(liquidityGauge), MAX_UINT);
            vm.stopPrank();

            vm.prank(admin);
            _liquidityGauge.set_reward_distributor(address(token), ownerGauge);
            vm.stopPrank();
            unchecked {
                ++i;
            }
        }
    }
    struct DistributionGauge {
        address token;
        uint256 amount;
    }
    function _distributeGaugeRewards(DistributionGauge[] memory distributionGauges) internal {
        ISDLiquidityGauge _liquidityGauge = ISDLiquidityGauge(address(liquidityGauge));
        for (uint256 i; i < distributionGauges.length; ) {
            vm.prank(ownerGauge);
            deal(distributionGauges[i].token, ownerGauge, distributionGauges[i].amount);
            vm.prank(ownerGauge);
            _liquidityGauge.deposit_reward_token(distributionGauges[i].token, distributionGauges[i].amount);
            unchecked {
                ++i;
            }
        }
        vm.stopPrank();
    }
}
