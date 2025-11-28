// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract ProcessLockRewards is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;

    uint208 amountLocked1 = 10_000 ether;
    uint208 amountLocked2 = 333_333 ether;

    uint256 USGToDistribute = 20_000 ether;
    uint256 amount2ToDistribute = 500 * 10 ** 6;
    uint256 amount3ToDistribute = 30_000 ether;

    function setUp() external {
        deal(address(tan), usr1, amountLocked1);
        deal(address(tan), usr2, amountLocked2);

        // 1 is permalocked
        vm.startPrank(usr1);
        tan.approve(address(vsTan), MAX_UINT);
        vsTan.createLock(amountLocked1, true);
        vm.stopPrank();

        // 2 is permalocked
        vm.startPrank(usr2);
        tan.approve(address(vsTan), MAX_UINT);
        vsTan.createLock(amountLocked2, false);
        vm.stopPrank();

        // Prepare distribution
        vm.startPrank(owner);
        usg.approve(address(vsTan), MAX_UINT);
        deal(address(usg), address(owner), USGToDistribute * 10);
        vm.stopPrank();
    }
    function test_processRewards_success() external {
        // Process the rewards when period is finished
        vm.startPrank(owner);

        verifyLostDeltaAbsERC20(usg, owner, USGToDistribute, 1_000_000, "usg transfered by owner");
        verifyReceiveDeltaAbsERC20(usg, address(vsTan), USGToDistribute, 1_000_000, "usg transfered to VsTAN");

        TokenAmount[] memory tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: usg, amount: USGToDistribute});
        vsTan.processRewards(tokenAmounts);

        Reward memory rDataUSG = vsTan.getRewardData(usg);

        assertEq(rDataUSG.periodFinish, block.timestamp + 1 weeks);
        assertEq(rDataUSG.lastUpdateTime, block.timestamp);
        assertEq(rDataUSG.rewardRate, USGToDistribute / 1 weeks);
        assertERC20Tracking();

        // Process the rewards when period is not finished, we pass in the else
        skip(6 days);

        verifyLostDeltaAbsERC20(usg, owner, USGToDistribute, 1_000_000, "usg transfered by owner");
        verifyReceiveDeltaAbsERC20(usg, address(vsTan), USGToDistribute, 1_000_000, "usg transfered to VsTAN");

        uint256 leftOver = (rDataUSG.periodFinish - block.timestamp) * rDataUSG.rewardRate;
        uint256 rateExpected = ((leftOver + USGToDistribute) / 1 weeks);
        vsTan.processRewards(tokenAmounts);

        rDataUSG = vsTan.getRewardData(usg);
        assertEq(rDataUSG.periodFinish, block.timestamp + 1 weeks);
        assertEq(rDataUSG.lastUpdateTime, block.timestamp);
        assertEq(rDataUSG.rewardRate, rateExpected);
        assertERC20Tracking();

        // Process the rewards when period is finished again
        skip(7 days);

        verifyLostDeltaAbsERC20(usg, owner, USGToDistribute, 1_000_000, "usg transfered by owner");
        verifyReceiveDeltaAbsERC20(usg, address(vsTan), USGToDistribute, 1_000_000, "usg transfered to VsTAN");

        rateExpected = USGToDistribute / 1 weeks;
        vsTan.processRewards(tokenAmounts);

        rDataUSG = vsTan.getRewardData(usg);
        assertEq(rDataUSG.periodFinish, block.timestamp + 1 weeks);
        assertEq(rDataUSG.lastUpdateTime, block.timestamp);
        assertEq(rDataUSG.rewardRate, rateExpected);
        assertERC20Tracking();

        // Add some new rewards tokens
        skip(7 days);
        deal(address(AddrClassicERC20.USDT), address(owner), amount2ToDistribute * 3);
        deal(address(AddrClassicERC20.CRV), address(owner), amount3ToDistribute * 3);

        AddrClassicERC20.USDT.forceApprove(address(vsTan), MAX_UINT);
        AddrClassicERC20.CRV.forceApprove(address(vsTan), MAX_UINT);

        vsTan.addNewReward(AddrClassicERC20.USDT);
        vsTan.addNewReward(AddrClassicERC20.CRV);

        TokenAmount[] memory tokenAmounts2 = new TokenAmount[](3);
        tokenAmounts2[0] = TokenAmount({token: AddrClassicERC20.USDT, amount: amount2ToDistribute});
        tokenAmounts2[1] = TokenAmount({token: AddrClassicERC20.CRV, amount: amount3ToDistribute});
        tokenAmounts2[2] = TokenAmount({token: usg, amount: USGToDistribute});

        // Do a processRewards with several tokens not in the same order of creation
        verifyLostDeltaAbsERC20(usg, owner, USGToDistribute, 1_000_000, "usg transfered by owner");
        verifyReceiveDeltaAbsERC20(usg, address(vsTan), USGToDistribute, 1_000_000, "usg transfered to VsTAN");

        verifyLostDeltaAbsERC20(AddrClassicERC20.USDT, owner, amount2ToDistribute, 1_000_000, "USDT transfered by owner");
        verifyReceiveDeltaAbsERC20(AddrClassicERC20.USDT, address(vsTan), amount2ToDistribute, 1_000_000, "USDT transfered to VsTAN");

        verifyLostDeltaAbsERC20(AddrClassicERC20.CRV, owner, amount3ToDistribute, 1_000_000, "CRV transfered by owner");
        verifyReceiveDeltaAbsERC20(AddrClassicERC20.CRV, address(vsTan), amount3ToDistribute, 1_000_000, "CRV transfered to VsTAN");

        vsTan.processRewards(tokenAmounts2);

        rDataUSG = vsTan.getRewardData(usg);
        Reward memory rDataUSDT = vsTan.getRewardData(AddrClassicERC20.USDT);
        Reward memory rDataCRV = vsTan.getRewardData(AddrClassicERC20.CRV);

        assertEq(rDataUSG.periodFinish, block.timestamp + 1 weeks);
        assertEq(rDataUSG.lastUpdateTime, block.timestamp);
        assertEq(rDataUSG.rewardRate, USGToDistribute / 1 weeks);

        assertEq(rDataUSDT.periodFinish, block.timestamp + 1 weeks);
        assertEq(rDataUSDT.lastUpdateTime, block.timestamp);
        assertEq(rDataUSDT.rewardRate, amount2ToDistribute / 1 weeks);

        assertEq(rDataCRV.periodFinish, block.timestamp + 1 weeks);
        assertEq(rDataCRV.lastUpdateTime, block.timestamp);
        assertEq(rDataCRV.rewardRate, amount3ToDistribute / 1 weeks);
        assertERC20Tracking();

        vm.stopPrank();

        skip(1 weeks);

        uint256 totalUSGDistributed = 4 * USGToDistribute;

        uint256 USGClaimExpected = (totalUSGDistributed * amountLocked1) / (amountLocked1 + amountLocked2);
        uint256 USDTClaimExpected = (amount2ToDistribute * amountLocked1) / (amountLocked1 + amountLocked2);
        uint256 crvClaimExpected = (amount3ToDistribute * amountLocked1) / (amountLocked1 + amountLocked2);

        verifyLostDeltaRelERC20(usg, address(vsTan), USGClaimExpected, 1e13, "usg claimed from VsTAN");
        verifyReceiveDeltaRelERC20(usg, usr1, USGClaimExpected, 1e13, "usg claimed and received by the user");

        verifyLostDeltaRelERC20(AddrClassicERC20.USDT, address(vsTan), USDTClaimExpected, 1e15, "USDT claimed from VsTAN");
        verifyReceiveDeltaRelERC20(AddrClassicERC20.USDT, usr1, USDTClaimExpected, 1e15, "USDT claimed and received by the user");

        verifyLostDeltaRelERC20(AddrClassicERC20.CRV, address(vsTan), crvClaimExpected, 1e13, "CRV claimed from VsTAN");
        verifyReceiveDeltaRelERC20(AddrClassicERC20.CRV, usr1, crvClaimExpected, 1e13, "CRV claimed and received by the user");

        vm.prank(usr1);
        vsTan.claimSimple(1, false);

        assertERC20Tracking();

        USGClaimExpected = (totalUSGDistributed * amountLocked2) / (amountLocked1 + amountLocked2);
        USDTClaimExpected = (amount2ToDistribute * amountLocked2) / (amountLocked1 + amountLocked2);
        crvClaimExpected = (amount3ToDistribute * amountLocked2) / (amountLocked1 + amountLocked2);

        verifyLostDeltaRelERC20(usg, address(vsTan), USGClaimExpected, 1e13, "usg claimed from VsTAN");
        verifyReceiveDeltaRelERC20(usg, usr2, USGClaimExpected, 1e13, "usg claimed and received by the user");

        verifyLostDeltaRelERC20(AddrClassicERC20.USDT, address(vsTan), USDTClaimExpected, 1e15, "USDT claimed from VsTAN");
        verifyReceiveDeltaRelERC20(AddrClassicERC20.USDT, usr2, USDTClaimExpected, 1e15, "USDT claimed and received by the user");

        verifyLostDeltaRelERC20(AddrClassicERC20.CRV, address(vsTan), crvClaimExpected, 1e13, "CRV claimed from VsTAN");
        verifyReceiveDeltaRelERC20(AddrClassicERC20.CRV, usr2, crvClaimExpected, 1e13, "CRV claimed and received by the user");

        vm.prank(usr2);
        vsTan.claimSimple(2, false);

        assertERC20Tracking();
    }

    function test_processRewards_fails_when_not_owner() external {
        vm.startPrank(usr1);
        TokenAmount[] memory tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: usg, amount: USGToDistribute});

        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        vsTan.processRewards(tokenAmounts);
    }

    function test_processRewards_fails_when_try_to_distribute_token_that_is_not_a_reward() external {
        vm.startPrank(owner);
        TokenAmount[] memory tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: tan, amount: USGToDistribute});

        vm.expectRevert(abi.encodeWithSelector(VsTAN.RewardNotAdded.selector, address(tan)));
        vsTan.processRewards(tokenAmounts);
    }

    function test_processRewards_fails_when_try_to_distribute_0() external {
        vm.startPrank(owner);
        TokenAmount[] memory tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: usg, amount: 0});

        vm.expectRevert(abi.encodeWithSelector(VsTAN.ZeroAmount.selector));
        vsTan.processRewards(tokenAmounts);
    }
}
