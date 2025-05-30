// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract ClaimMultipleLock is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;

    uint208 amountLocked1 = 10_000 ether;
    uint208 amountLocked2 = 333_333 ether;

    uint256 tgUSDToDistribute = 20_000 ether;
    uint256 amount2ToDistribute = 10_000 * 10 ** 6;
    uint256 amount3ToDistribute = 30_000 ether;

    function setUp() external {
        deal(address(tan), usr1, amountLocked2 * 3);
        deal(address(tan), usr2, amountLocked2 * 2);

        vm.startPrank(usr1);
        tan.approve(address(rsTan), MAX_UINT);
        // 1 is permalocked
        rsTan.createLock(amountLocked1, true);
        // 2 is not permalocked
        rsTan.createLock(amountLocked2, false);
        // 3 is permalocked
        rsTan.createLock(amountLocked2, false);
        vm.stopPrank();

        vm.startPrank(usr2);
        tan.approve(address(rsTan), MAX_UINT);
        // 4 is permalocked
        rsTan.createLock(amountLocked1, true);
        // 5 is not permalocked
        rsTan.createLock(amountLocked2, true);
        vm.stopPrank();

        // Prepare distribution
        vm.startPrank(owner);
        tgUSD.approve(address(rsTan), MAX_UINT);
        deal(address(tgUSD), address(owner), tgUSDToDistribute * 10);

        TokenAmount[] memory tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: tgUSD, amount: tgUSDToDistribute});
        rsTan.processRewards(tokenAmounts);

        AddrClassicERC20.CRV.forceApprove(address(rsTan), MAX_UINT);
        deal(address(AddrClassicERC20.CRV), owner, amount3ToDistribute * 5);

        vm.stopPrank();
    }
    function test_claimMultiple_success() external {
        // Process the rewards when period is finished
        vm.startPrank(usr1);

        // Process the rewards when period is not finished, we pass in the else
        skip(6 days);

        uint256 totalTanLocked = rsTan.totalSupplyRsTan();

        // Claim 6/7 of 2 positions of USER1

        uint256 expectedTgUSDClaimable1 = (6 days * tgUSDToDistribute * amountLocked1) / (totalTanLocked * 1 weeks);
        uint256 expectedTgUSDClaimable3 = (6 days * tgUSDToDistribute * amountLocked2) / (totalTanLocked * 1 weeks);

        assertApproxEqRel(rsTan.claimableRewards(1)[0].amount, expectedTgUSDClaimable1, 1e5);
        assertApproxEqRel(rsTan.claimableRewards(3)[0].amount, expectedTgUSDClaimable3, 1e5);

        verifyLostDeltaRelERC20(tgUSD, address(rsTan), expectedTgUSDClaimable1 + expectedTgUSDClaimable3, 1e5, "TgUSD claimed, removed from rsTan");
        verifyReceiveDeltaRelERC20(tgUSD, usr1, expectedTgUSDClaimable1 + expectedTgUSDClaimable3, 1e5, "TgUSD claimed and transfered to usr");

        rsTan.claimMultiple(Array.memoryUint256([uint256(3), uint256(1)]), false);

        assertERC20Tracking();

        vm.stopPrank();

        skip(1 days);

        // Claim as tgUSD for USER2

        vm.startPrank(usr2);

        uint256 expectedTgUSDClaimable4 = (tgUSDToDistribute * amountLocked1) / totalTanLocked;
        uint256 expectedTgUSDClaimable5 = (tgUSDToDistribute * amountLocked2) / totalTanLocked;

        assertApproxEqRel(rsTan.claimableRewards(4)[0].amount, expectedTgUSDClaimable4, 1e5);
        assertApproxEqRel(rsTan.claimableRewards(5)[0].amount, expectedTgUSDClaimable5, 1e5);

        verifyLostDeltaRelERC20(tgUSD, address(rsTan), expectedTgUSDClaimable4 + expectedTgUSDClaimable5, 1e5, "TgUSD claimed, removed from rsTan");
        verifyReceiveDeltaRelERC20(tgUSD, usr2, expectedTgUSDClaimable4 + expectedTgUSDClaimable5, 1e5, "TgUSD claimed and transfered to usr");

        rsTan.claimMultiple(Array.memoryUint256([uint256(4), uint256(5)]), false);

        assertERC20Tracking();

        vm.stopPrank();

        // Claim as tgUSD for USER1

        vm.startPrank(usr1);

        expectedTgUSDClaimable1 = (1 days * tgUSDToDistribute * amountLocked1) / (totalTanLocked * 1 weeks);
        expectedTgUSDClaimable3 = (1 days * tgUSDToDistribute * amountLocked2) / (totalTanLocked * 1 weeks);
        uint256 expectedTgUSDClaimable2 = (tgUSDToDistribute * amountLocked2) / totalTanLocked;

        assertApproxEqRel(rsTan.claimableRewards(1)[0].amount, expectedTgUSDClaimable1, 1e5);
        assertApproxEqRel(rsTan.claimableRewards(2)[0].amount, expectedTgUSDClaimable2, 1e5);
        assertApproxEqRel(rsTan.claimableRewards(3)[0].amount, expectedTgUSDClaimable3, 1e5);

        uint256 tgUSDToClaim = expectedTgUSDClaimable1 + expectedTgUSDClaimable2 + expectedTgUSDClaimable3;

        uint256 sgUSDExpected = (tgUSDToClaim * 1e18) / sgUSD.pricePerShare();

        verifyLostDeltaRelERC20(tgUSD, address(rsTan), tgUSDToClaim, 1e5, "TgUSD claimed, removed from rsTan");
        verifyReceiveDeltaRelERC20(tgUSD, address(sgUSD), tgUSDToClaim, 1e5, "TgUSD deposited to sgUSD");

        verifyReceiveDeltaRelERC20(sgUSD, address(usr1), sgUSDExpected, 1e5, "SgUSD received as user claied as sgUSD");

        rsTan.claimMultiple(Array.memoryUint256([uint256(2), uint256(3), uint256(1)]), true);
        assertERC20Tracking();

        vm.stopPrank();

        assertApproxEqAbs(tgUSD.balanceOf(address(rsTan)), 0, 3_000_000, "Almost nothing of tgUSD left on RsTan");

        vm.startPrank(owner);
        rsTan.addNewReward(AddrClassicERC20.CRV);

        {
            IERC20[] memory tokens = rsTan.getRewardTokens();
            assertEq(address(tokens[0]), address(tgUSD));
            assertEq(address(tokens[1]), address(AddrClassicERC20.CRV));

            rsTan.rewardPerToken(tgUSD);
            rsTan.rewardPerToken(AddrClassicERC20.CRV);

            assertEq(block.timestamp, rsTan.lastTimeRewardApplicable(tgUSD));
            assertEq(block.timestamp, rsTan.lastTimeRewardApplicable(AddrClassicERC20.CRV));
        }

        TokenAmount[] memory tokenAmounts = new TokenAmount[](2);
        tokenAmounts[0] = TokenAmount({token: AddrClassicERC20.CRV, amount: amount3ToDistribute});
        tokenAmounts[1] = TokenAmount({token: tgUSD, amount: tgUSDToDistribute});
        rsTan.processRewards(tokenAmounts);

        vm.stopPrank();

        skip(4 days);

        expectedTgUSDClaimable1 = (4 days * tgUSDToDistribute * amountLocked1) / (totalTanLocked * 1 weeks);
        uint256 expectedCRVClaimable1 = (4 days * amount3ToDistribute * amountLocked1) / (totalTanLocked * 1 weeks);

        verifyLostDeltaRelERC20(tgUSD, address(rsTan), expectedTgUSDClaimable1, 1e5, "TgUSD claimed, removed from rsTan");
        verifyReceiveDeltaRelERC20(tgUSD, usr1, expectedTgUSDClaimable1, 1e5, "TgUSD claimed and received by usr1");

        verifyLostDeltaRelERC20(AddrClassicERC20.CRV, address(rsTan), expectedCRVClaimable1, 1e5, "CRV claimed, removed from rsTan");
        verifyReceiveDeltaRelERC20(AddrClassicERC20.CRV, usr1, expectedCRVClaimable1, 1e5, "CRV claimed by usr1");

        vm.startPrank(usr1);
        rsTan.claimSimple(1, false);
        vm.stopPrank();

        assertERC20Tracking();

        skip(8 days);

        // Claim multiple on User1

        vm.startPrank(usr1);

        expectedTgUSDClaimable1 = (3 days * tgUSDToDistribute * amountLocked1) / (totalTanLocked * 1 weeks);
        expectedCRVClaimable1 = (3 days * amount3ToDistribute * amountLocked1) / (totalTanLocked * 1 weeks);

        expectedTgUSDClaimable2 = (tgUSDToDistribute * amountLocked2) / totalTanLocked;
        uint256 expectedCRVClaimable2 = (amount3ToDistribute * amountLocked2) / totalTanLocked;

        expectedTgUSDClaimable3 = (tgUSDToDistribute * amountLocked2) / totalTanLocked;
        uint256 expectedCRVClaimable3 = (amount3ToDistribute * amountLocked2) / totalTanLocked;

        verifyLostDeltaRelERC20(tgUSD, address(rsTan), expectedTgUSDClaimable1 + expectedTgUSDClaimable2 + expectedTgUSDClaimable3, 1e5, "TgUSD claimed, removed from rsTan");
        verifyReceiveDeltaRelERC20(tgUSD, usr1, expectedTgUSDClaimable1 + expectedTgUSDClaimable2 + expectedTgUSDClaimable3, 1e5, "TgUSD claimed and received by usr1");

        verifyLostDeltaRelERC20(AddrClassicERC20.CRV, address(rsTan), expectedCRVClaimable1 + expectedCRVClaimable2 + expectedCRVClaimable3, 1e5, "CRV claimed");
        verifyReceiveDeltaRelERC20(AddrClassicERC20.CRV, usr1, expectedCRVClaimable1 + expectedCRVClaimable2 + expectedCRVClaimable3, 1e5, "CRV claimed by usr1");

        rsTan.claimMultiple(Array.memoryUint256([uint256(3), uint256(2), uint256(1)]), false);
        vm.stopPrank();

        assertERC20Tracking();

        // Process only one of the rewards
        vm.startPrank(owner);
        tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: AddrClassicERC20.CRV, amount: amount3ToDistribute});
        rsTan.processRewards(tokenAmounts);

        vm.stopPrank();

        skip(7 days);

        // Claim Multiple on user 2. Claim tgUSD and CRV from distribution N-1 and CRV from N.

        vm.startPrank(usr2);

        expectedTgUSDClaimable4 = (tgUSDToDistribute * amountLocked1) / totalTanLocked;
        uint256 expectedCRVClaimable4 = (2 * (amount3ToDistribute * amountLocked1)) / totalTanLocked;

        expectedTgUSDClaimable5 = (tgUSDToDistribute * amountLocked2) / totalTanLocked;
        uint256 expectedCRVClaimable5 = (2 * (amount3ToDistribute * amountLocked2)) / totalTanLocked;

        verifyLostDeltaRelERC20(tgUSD, address(rsTan), expectedTgUSDClaimable4 + expectedTgUSDClaimable5, 1e5, "TgUSD claimed, removed from rsTan");
        verifyReceiveDeltaRelERC20(tgUSD, usr2, expectedTgUSDClaimable4 + expectedTgUSDClaimable5, 1e5, "TgUSD claimed and received by usr2");

        verifyLostDeltaRelERC20(AddrClassicERC20.CRV, address(rsTan), expectedCRVClaimable4 + expectedCRVClaimable5, 1e5, "CRV claimed");
        verifyReceiveDeltaRelERC20(AddrClassicERC20.CRV, usr2, expectedCRVClaimable4 + expectedCRVClaimable5, 1e5, "CRV claimed by usr2");

        rsTan.claimMultiple(Array.memoryUint256([uint256(5), uint256(4)]), false);
        vm.stopPrank();

        assertERC20Tracking();

        // Claim Multiple on user 1. Claim  CRV only because tgUSD already claimed before

        vm.startPrank(usr1);

        verifyLostERC20(tgUSD, address(rsTan), 0, "TgUSD claimed nothing at all");
        verifyReceiveERC20(tgUSD, usr1, 0, "TgUSD claimed nothing at all");

        verifyLostDeltaRelERC20(AddrClassicERC20.CRV, address(rsTan), expectedCRVClaimable4 / 2 + expectedCRVClaimable5, 1e5, "CRV claimed");
        verifyReceiveDeltaRelERC20(AddrClassicERC20.CRV, usr1, expectedCRVClaimable4 / 2 + expectedCRVClaimable5, 1e5, "CRV claimed by usr1");

        rsTan.claimMultiple(Array.memoryUint256([uint256(1), uint256(2), uint256(3)]), true);
        vm.stopPrank();

        assertERC20Tracking();
    }

    function test_claimMultiple_fails_if_no_rewards_at_all_are_claimable() external {
        vm.startPrank(usr1);

        uint256[] memory ids = Array.memoryUint256([uint256(2), uint256(1), uint256(4)]);

        vm.expectRevert(abi.encodeWithSelector(RsTan.NothingToClaim.selector));
        rsTan.claimMultiple(ids, false);
    }

    function test_claimMultiple_fails_with_one_position_not_owned() external {
        skip(1 days);
        vm.startPrank(usr1);

        uint256[] memory ids = Array.memoryUint256([uint256(2), uint256(1), uint256(4)]);

        vm.expectRevert(abi.encodeWithSelector(RsTan.NotTokenOwner.selector));
        rsTan.claimMultiple(ids, false);
    }
}
