// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract ProcessLockRewards is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;

    uint208 amountLocked1 = 10_000 ether;
    uint208 amountLocked2 = 333_333 ether;

    uint256 tgUSDToDistribute = 20_000 ether;
    uint256 amount2ToDistribute = 10_000 * 10 ** 6;
    uint256 amount3ToDistribute = 30_000 ether;

    function setUp() external {
        deal(address(tan), usr1, amountLocked1);
        deal(address(tan), usr2, amountLocked2);

        // 1 is permalocked
        vm.startPrank(usr1);
        tan.approve(address(rsTan), MAX_UINT);
        rsTan.createLock(amountLocked1, true);
        vm.stopPrank();

        // 2 is permalocked
        vm.startPrank(usr2);
        tan.approve(address(rsTan), MAX_UINT);
        rsTan.createLock(amountLocked2, false);
        vm.stopPrank();

        // Prepare distribution
        vm.startPrank(owner);
        tgUSD.approve(address(rsTan), MAX_UINT);
        deal(address(tgUSD), address(owner), tgUSDToDistribute * 10);
        vm.stopPrank();
    }
    function test_processRewards_success() external {
        // Process the rewards when period is finished
        vm.startPrank(owner);

        verifyLostERC20(tgUSD, owner, tgUSDToDistribute, "TgUSD transfered by owner");
        verifyReceiveERC20(tgUSD, address(rsTan), tgUSDToDistribute, "TgUSD transfered to RsTan");

        TokenAmount[] memory tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: tgUSD, amount: tgUSDToDistribute});
        rsTan.processRewards(tokenAmounts);

        Reward memory rDataTgUSD = rsTan.getRewardData(tgUSD);

        assertEq(rDataTgUSD.periodFinish, block.timestamp + 1 weeks);
        assertEq(rDataTgUSD.lastUpdateTime, block.timestamp);
        assertEq(rDataTgUSD.rewardRate, tgUSDToDistribute / 1 weeks);
        assertERC20Tracking();

        // Process the rewards when period is not finished, we pass in the else
        skip(6 days);

        verifyLostERC20(tgUSD, owner, tgUSDToDistribute, "TgUSD transfered by owner");
        verifyReceiveERC20(tgUSD, address(rsTan), tgUSDToDistribute, "TgUSD transfered to RsTan");

        uint256 leftOver = (rDataTgUSD.periodFinish - block.timestamp) * rDataTgUSD.rewardRate;
        uint256 rateExpected = ((leftOver + tgUSDToDistribute) / 1 weeks);
        rsTan.processRewards(tokenAmounts);

        rDataTgUSD = rsTan.getRewardData(tgUSD);
        assertEq(rDataTgUSD.periodFinish, block.timestamp + 1 weeks);
        assertEq(rDataTgUSD.lastUpdateTime, block.timestamp);
        assertEq(rDataTgUSD.rewardRate, rateExpected);
        assertERC20Tracking();

        // Process the rewards when period is finished again
        skip(7 days);

        verifyLostERC20(tgUSD, owner, tgUSDToDistribute, "TgUSD transfered by owner");
        verifyReceiveERC20(tgUSD, address(rsTan), tgUSDToDistribute, "TgUSD transfered to RsTan");

        rateExpected = tgUSDToDistribute / 1 weeks;
        rsTan.processRewards(tokenAmounts);

        rDataTgUSD = rsTan.getRewardData(tgUSD);
        assertEq(rDataTgUSD.periodFinish, block.timestamp + 1 weeks);
        assertEq(rDataTgUSD.lastUpdateTime, block.timestamp);
        assertEq(rDataTgUSD.rewardRate, rateExpected);
        assertERC20Tracking();

        // Add some new rewards tokens
        skip(7 days);
        deal(address(AddrClassicERC20.USDT), address(owner), amount2ToDistribute * 3);
        deal(address(AddrClassicERC20.CRV), address(owner), amount3ToDistribute * 3);

        AddrClassicERC20.USDT.forceApprove(address(rsTan), MAX_UINT);
        AddrClassicERC20.CRV.forceApprove(address(rsTan), MAX_UINT);

        rsTan.addNewReward(AddrClassicERC20.USDT);
        rsTan.addNewReward(AddrClassicERC20.CRV);

        TokenAmount[] memory tokenAmounts2 = new TokenAmount[](3);
        tokenAmounts2[0] = TokenAmount({token: AddrClassicERC20.USDT, amount: amount2ToDistribute});
        tokenAmounts2[1] = TokenAmount({token: AddrClassicERC20.CRV, amount: amount3ToDistribute});
        tokenAmounts2[2] = TokenAmount({token: tgUSD, amount: tgUSDToDistribute});

        // Do a processRewards with several tokens not in the same order of creation
        verifyLostERC20(tgUSD, owner, tgUSDToDistribute, "TgUSD transfered by owner");
        verifyReceiveERC20(tgUSD, address(rsTan), tgUSDToDistribute, "TgUSD transfered to RsTan");

        verifyLostERC20(AddrClassicERC20.USDT, owner, amount2ToDistribute, "USDT transfered by owner");
        verifyReceiveERC20(AddrClassicERC20.USDT, address(rsTan), amount2ToDistribute, "USDT transfered to RsTan");

        verifyLostERC20(AddrClassicERC20.CRV, owner, amount3ToDistribute, "CRV transfered by owner");
        verifyReceiveERC20(AddrClassicERC20.CRV, address(rsTan), amount3ToDistribute, "CRV transfered to RsTan");

        rsTan.processRewards(tokenAmounts2);

        rDataTgUSD = rsTan.getRewardData(tgUSD);
        Reward memory rDataUSDT = rsTan.getRewardData(AddrClassicERC20.USDT);
        Reward memory rDataCRV = rsTan.getRewardData(AddrClassicERC20.CRV);

        assertEq(rDataTgUSD.periodFinish, block.timestamp + 1 weeks);
        assertEq(rDataTgUSD.lastUpdateTime, block.timestamp);
        assertEq(rDataTgUSD.rewardRate, tgUSDToDistribute / 1 weeks);

        assertEq(rDataUSDT.periodFinish, block.timestamp + 1 weeks);
        assertEq(rDataUSDT.lastUpdateTime, block.timestamp);
        assertEq(rDataUSDT.rewardRate, amount2ToDistribute / 1 weeks);

        assertEq(rDataCRV.periodFinish, block.timestamp + 1 weeks);
        assertEq(rDataCRV.lastUpdateTime, block.timestamp);
        assertEq(rDataCRV.rewardRate, amount3ToDistribute / 1 weeks);
        assertERC20Tracking();

        vm.stopPrank();

        skip(1 weeks);

        uint256 totalTgUSDDistributed = 4 * tgUSDToDistribute;

        uint256 tgUSDClaimExpected = (totalTgUSDDistributed * amountLocked1) / (amountLocked1 + amountLocked2);
        uint256 USDTClaimExpected = (amount2ToDistribute * amountLocked1) / (amountLocked1 + amountLocked2);
        uint256 crvClaimExpected = (amount3ToDistribute * amountLocked1) / (amountLocked1 + amountLocked2);

        verifyLostDeltaRelERC20(tgUSD, address(rsTan), tgUSDClaimExpected, 1e13, "TgUSD claimed from RsTan");
        verifyReceiveDeltaRelERC20(tgUSD, usr1, tgUSDClaimExpected, 1e13, "TgUSD claimed and received by the user");

        verifyLostDeltaRelERC20(AddrClassicERC20.USDT, address(rsTan), USDTClaimExpected, 5e13, "USDT claimed from RsTan");
        verifyReceiveDeltaRelERC20(AddrClassicERC20.USDT, usr1, USDTClaimExpected, 5e13, "USDT claimed and received by the user");

        verifyLostDeltaRelERC20(AddrClassicERC20.CRV, address(rsTan), crvClaimExpected, 1e13, "CRV claimed from RsTan");
        verifyReceiveDeltaRelERC20(AddrClassicERC20.CRV, usr1, crvClaimExpected, 1e13, "CRV claimed and received by the user");

        vm.prank(usr1);
        rsTan.claimSimple(1, false);

        assertERC20Tracking();

        tgUSDClaimExpected = (totalTgUSDDistributed * amountLocked2) / (amountLocked1 + amountLocked2);
        USDTClaimExpected = (amount2ToDistribute * amountLocked2) / (amountLocked1 + amountLocked2);
        crvClaimExpected = (amount3ToDistribute * amountLocked2) / (amountLocked1 + amountLocked2);

        verifyLostDeltaRelERC20(tgUSD, address(rsTan), tgUSDClaimExpected, 1e13, "TgUSD claimed from RsTan");
        verifyReceiveDeltaRelERC20(tgUSD, usr2, tgUSDClaimExpected, 1e13, "TgUSD claimed and received by the user");

        verifyLostDeltaRelERC20(AddrClassicERC20.USDT, address(rsTan), USDTClaimExpected, 5e13, "USDT claimed from RsTan");
        verifyReceiveDeltaRelERC20(AddrClassicERC20.USDT, usr2, USDTClaimExpected, 5e13, "USDT claimed and received by the user");

        verifyLostDeltaRelERC20(AddrClassicERC20.CRV, address(rsTan), crvClaimExpected, 1e13, "CRV claimed from RsTan");
        verifyReceiveDeltaRelERC20(AddrClassicERC20.CRV, usr2, crvClaimExpected, 1e13, "CRV claimed and received by the user");

        vm.prank(usr2);
        rsTan.claimSimple(2, false);

        assertERC20Tracking();
    }

    function test_processRewards_fails_when_not_owner() external {
        vm.startPrank(usr1);
        TokenAmount[] memory tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: tan, amount: tgUSDToDistribute});

        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        rsTan.processRewards(tokenAmounts);

        console.logBytes(abi.encodeWithSignature("ZeroDebtAmount()"));
    }
}
