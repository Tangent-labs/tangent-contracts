// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract ClaimMultipleLock is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;

    uint208 amountLocked1 = 10_000 ether;
    uint208 amountLocked2 = 333_333 ether;

    uint256 USGToDistribute = 20_000 ether;
    uint256 amount2ToDistribute = 10_000 * 10 ** 6;
    uint256 amount3ToDistribute = 30_000 ether;

    function setUp() external {
        deal(address(tan), usr1, amountLocked2 * 3);
        deal(address(tan), usr2, amountLocked2 * 2);

        vm.startPrank(usr1);
        tan.approve(address(vsTan), MAX_UINT);
        // 1 is permalocked
        vsTan.createLock(amountLocked1, true);
        // 2 is not permalocked
        vsTan.createLock(amountLocked2, false);
        // 3 is permalocked
        vsTan.createLock(amountLocked2, false);
        vm.stopPrank();

        vm.startPrank(usr2);
        tan.approve(address(vsTan), MAX_UINT);
        // 4 is permalocked
        vsTan.createLock(amountLocked1, true);
        // 5 is not permalocked
        vsTan.createLock(amountLocked2, true);
        vm.stopPrank();

        // Prepare distribution
        vm.startPrank(owner);
        usg.approve(address(vsTan), MAX_UINT);
        deal(address(usg), address(owner), USGToDistribute * 10);

        TokenAmount[] memory tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: usg, amount: USGToDistribute});
        vsTan.processRewards(tokenAmounts);

        AddrClassicERC20.CRV.forceApprove(address(vsTan), MAX_UINT);
        deal(address(AddrClassicERC20.CRV), owner, amount3ToDistribute * 5);

        vm.stopPrank();
    }
    function test_claimMultiple_success() external {
        // Process the rewards when period is finished
        vm.startPrank(usr1);

        // Process the rewards when period is not finished, we pass in the else
        skip(6 days);

        uint256 totalTanLocked = vsTan.totalSupplyVsTan();

        // Claim 6/7 of 2 positions of USER1

        uint256 expectedUSGClaimable1 = (6 days * USGToDistribute * amountLocked1) / (totalTanLocked * 1 weeks);
        uint256 expectedUSGClaimable3 = (6 days * USGToDistribute * amountLocked2) / (totalTanLocked * 1 weeks);

        assertApproxEqRel(vsTan.claimableRewards(1)[0].amount, expectedUSGClaimable1, 1e5);
        assertApproxEqRel(vsTan.claimableRewards(3)[0].amount, expectedUSGClaimable3, 1e5);

        verifyLostDeltaRelERC20(usg, address(vsTan), expectedUSGClaimable1 + expectedUSGClaimable3, 1e5, "usg claimed, removed from vsTan");
        verifyReceiveDeltaRelERC20(usg, usr1, expectedUSGClaimable1 + expectedUSGClaimable3, 1e5, "usg claimed and transfered to usr");

        vsTan.claimMultiple(Array.memoryUint256([uint256(3), uint256(1)]), false);

        assertERC20Tracking();

        vm.stopPrank();

        skip(1 days);

        // Claim as usg for USER2

        vm.startPrank(usr2);

        uint256 expectedUSGClaimable4 = (USGToDistribute * amountLocked1) / totalTanLocked;
        uint256 expectedUSGClaimable5 = (USGToDistribute * amountLocked2) / totalTanLocked;

        assertApproxEqRel(vsTan.claimableRewards(4)[0].amount, expectedUSGClaimable4, 1e5);
        assertApproxEqRel(vsTan.claimableRewards(5)[0].amount, expectedUSGClaimable5, 1e5);

        verifyLostDeltaRelERC20(usg, address(vsTan), expectedUSGClaimable4 + expectedUSGClaimable5, 1e5, "usg claimed, removed from vsTan");
        verifyReceiveDeltaRelERC20(usg, usr2, expectedUSGClaimable4 + expectedUSGClaimable5, 1e5, "usg claimed and transfered to usr");

        vsTan.claimMultiple(Array.memoryUint256([uint256(4), uint256(5)]), false);

        assertERC20Tracking();

        vm.stopPrank();

        // Claim as usg for USER1

        vm.startPrank(usr1);

        expectedUSGClaimable1 = (1 days * USGToDistribute * amountLocked1) / (totalTanLocked * 1 weeks);
        expectedUSGClaimable3 = (1 days * USGToDistribute * amountLocked2) / (totalTanLocked * 1 weeks);
        uint256 expectedUSGClaimable2 = (USGToDistribute * amountLocked2) / totalTanLocked;

        assertApproxEqRel(vsTan.claimableRewards(1)[0].amount, expectedUSGClaimable1, 1e5);
        assertApproxEqRel(vsTan.claimableRewards(2)[0].amount, expectedUSGClaimable2, 1e5);
        assertApproxEqRel(vsTan.claimableRewards(3)[0].amount, expectedUSGClaimable3, 1e5);

        uint256 USGToClaim = expectedUSGClaimable1 + expectedUSGClaimable2 + expectedUSGClaimable3;

        uint256 sUSGExpected = (USGToClaim * 1e18) / sUSG.pricePerShare();

        verifyLostDeltaRelERC20(usg, address(vsTan), USGToClaim, 1e5, "usg claimed, removed from vsTan");
        verifyReceiveDeltaRelERC20(usg, address(sUSG), USGToClaim, 1e5, "usg deposited to sUSG");

        verifyReceiveDeltaRelERC20(sUSG, address(usr1), sUSGExpected, 1e5, "sUSG received as user claied as sUSG");

        vsTan.claimMultiple(Array.memoryUint256([uint256(2), uint256(3), uint256(1)]), true);
        assertERC20Tracking();

        vm.stopPrank();

        assertApproxEqAbs(usg.balanceOf(address(vsTan)), 0, 3_000_000, "Almost nothing of usg left on VsTAN");

        vm.startPrank(owner);
        vsTan.addNewReward(AddrClassicERC20.CRV);

        {
            IERC20[] memory tokens = vsTan.getRewardTokens();
            assertEq(address(tokens[0]), address(usg));
            assertEq(address(tokens[1]), address(AddrClassicERC20.CRV));

            vsTan.rewardPerToken(usg);
            vsTan.rewardPerToken(AddrClassicERC20.CRV);

            assertEq(block.timestamp, vsTan.lastTimeRewardApplicable(usg));
            assertEq(block.timestamp, vsTan.lastTimeRewardApplicable(AddrClassicERC20.CRV));
        }

        TokenAmount[] memory tokenAmounts = new TokenAmount[](2);
        tokenAmounts[0] = TokenAmount({token: AddrClassicERC20.CRV, amount: amount3ToDistribute});
        tokenAmounts[1] = TokenAmount({token: usg, amount: USGToDistribute});
        vsTan.processRewards(tokenAmounts);

        vm.stopPrank();

        skip(4 days);

        expectedUSGClaimable1 = (4 days * USGToDistribute * amountLocked1) / (totalTanLocked * 1 weeks);
        uint256 expectedCRVClaimable1 = (4 days * amount3ToDistribute * amountLocked1) / (totalTanLocked * 1 weeks);

        verifyLostDeltaRelERC20(usg, address(vsTan), expectedUSGClaimable1, 1e5, "usg claimed, removed from vsTan");
        verifyReceiveDeltaRelERC20(usg, usr1, expectedUSGClaimable1, 1e5, "usg claimed and received by usr1");

        verifyLostDeltaRelERC20(AddrClassicERC20.CRV, address(vsTan), expectedCRVClaimable1, 1e5, "CRV claimed, removed from vsTan");
        verifyReceiveDeltaRelERC20(AddrClassicERC20.CRV, usr1, expectedCRVClaimable1, 1e5, "CRV claimed by usr1");

        vm.startPrank(usr1);
        vsTan.claimSimple(1, false);
        vm.stopPrank();

        assertERC20Tracking();

        skip(8 days);

        // Claim multiple on User1

        vm.startPrank(usr1);

        expectedUSGClaimable1 = (3 days * USGToDistribute * amountLocked1) / (totalTanLocked * 1 weeks);
        expectedCRVClaimable1 = (3 days * amount3ToDistribute * amountLocked1) / (totalTanLocked * 1 weeks);

        expectedUSGClaimable2 = (USGToDistribute * amountLocked2) / totalTanLocked;
        uint256 expectedCRVClaimable2 = (amount3ToDistribute * amountLocked2) / totalTanLocked;

        expectedUSGClaimable3 = (USGToDistribute * amountLocked2) / totalTanLocked;
        uint256 expectedCRVClaimable3 = (amount3ToDistribute * amountLocked2) / totalTanLocked;

        verifyLostDeltaRelERC20(usg, address(vsTan), expectedUSGClaimable1 + expectedUSGClaimable2 + expectedUSGClaimable3, 1e5, "usg claimed, removed from vsTan");
        verifyReceiveDeltaRelERC20(usg, usr1, expectedUSGClaimable1 + expectedUSGClaimable2 + expectedUSGClaimable3, 1e5, "usg claimed and received by usr1");

        verifyLostDeltaRelERC20(AddrClassicERC20.CRV, address(vsTan), expectedCRVClaimable1 + expectedCRVClaimable2 + expectedCRVClaimable3, 1e5, "CRV claimed");
        verifyReceiveDeltaRelERC20(AddrClassicERC20.CRV, usr1, expectedCRVClaimable1 + expectedCRVClaimable2 + expectedCRVClaimable3, 1e5, "CRV claimed by usr1");

        vsTan.claimMultiple(Array.memoryUint256([uint256(3), uint256(2), uint256(1)]), false);
        vm.stopPrank();

        assertERC20Tracking();

        // Process only one of the rewards
        vm.startPrank(owner);
        tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: AddrClassicERC20.CRV, amount: amount3ToDistribute});
        vsTan.processRewards(tokenAmounts);

        vm.stopPrank();

        skip(7 days);

        // Claim Multiple on user 2. Claim usg and CRV from distribution N-1 and CRV from N.

        vm.startPrank(usr2);

        expectedUSGClaimable4 = (USGToDistribute * amountLocked1) / totalTanLocked;
        uint256 expectedCRVClaimable4 = (2 * (amount3ToDistribute * amountLocked1)) / totalTanLocked;

        expectedUSGClaimable5 = (USGToDistribute * amountLocked2) / totalTanLocked;
        uint256 expectedCRVClaimable5 = (2 * (amount3ToDistribute * amountLocked2)) / totalTanLocked;

        verifyLostDeltaRelERC20(usg, address(vsTan), expectedUSGClaimable4 + expectedUSGClaimable5, 1e5, "usg claimed, removed from vsTan");
        verifyReceiveDeltaRelERC20(usg, usr2, expectedUSGClaimable4 + expectedUSGClaimable5, 1e5, "usg claimed and received by usr2");

        verifyLostDeltaRelERC20(AddrClassicERC20.CRV, address(vsTan), expectedCRVClaimable4 + expectedCRVClaimable5, 1e5, "CRV claimed");
        verifyReceiveDeltaRelERC20(AddrClassicERC20.CRV, usr2, expectedCRVClaimable4 + expectedCRVClaimable5, 1e5, "CRV claimed by usr2");

        vsTan.claimMultiple(Array.memoryUint256([uint256(5), uint256(4)]), false);
        vm.stopPrank();

        assertERC20Tracking();

        // Claim Multiple on user 1. Claim  CRV only because usg already claimed before

        vm.startPrank(usr1);

        verifyLostERC20(usg, address(vsTan), 0, "usg claimed nothing at all");
        verifyReceiveERC20(usg, usr1, 0, "usg claimed nothing at all");

        verifyLostDeltaRelERC20(AddrClassicERC20.CRV, address(vsTan), expectedCRVClaimable4 / 2 + expectedCRVClaimable5, 1e5, "CRV claimed");
        verifyReceiveDeltaRelERC20(AddrClassicERC20.CRV, usr1, expectedCRVClaimable4 / 2 + expectedCRVClaimable5, 1e5, "CRV claimed by usr1");

        vsTan.claimMultiple(Array.memoryUint256([uint256(1), uint256(2), uint256(3)]), true);
        vm.stopPrank();

        assertERC20Tracking();
    }

    function test_claimMultiple_fails_if_no_rewards_at_all_are_claimable() external {
        vm.startPrank(usr1);

        uint256[] memory ids = Array.memoryUint256([uint256(2), uint256(1), uint256(4)]);

        vm.expectRevert(abi.encodeWithSelector(VsTAN.NothingToClaim.selector));
        vsTan.claimMultiple(ids, false);
    }

    function test_claimMultiple_fails_with_one_position_not_owned() external {
        skip(1 days);
        vm.startPrank(usr1);

        uint256[] memory ids = Array.memoryUint256([uint256(2), uint256(1), uint256(4)]);

        vm.expectRevert(abi.encodeWithSelector(VsTAN.NotTokenOwner.selector));
        vsTan.claimMultiple(ids, false);
    }
}
