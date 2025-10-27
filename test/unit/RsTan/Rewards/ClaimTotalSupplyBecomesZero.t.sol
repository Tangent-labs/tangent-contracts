// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../handler/Features/HProcessRewards.sol";
import "../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
contract ClaimTotalSupplyBecomesZero is MarketDeploymentContext {
    function setUp() public {}

    //
    function test_claim_exploit_on_vsTAN() external {
        uint208 amount = 10_000 ether;
        vm.startPrank(usr1);
        deal(address(tan), usr1, amount);

        tan.approve(address(vsTan), MAX_UINT);
        vsTan.createLock(amount, false);

        vm.stopPrank();

        skip(13 weeks);

        vm.startPrank(owner);
        deal(address(usg), address(owner), 1_000 ether);
        usg.approve(address(vsTan), MAX_UINT);

        TokenAmount[] memory tokenAmounts = new TokenAmount[](1);
        tokenAmounts[0] = TokenAmount({token: usg, amount: 1_000 ether});

        vsTan.processRewards(tokenAmounts);
        vm.stopPrank();

        vm.prank(usr1);
        // Total collateral becomes 0

        skip(7 days);
        vsTan.unlock(1, true);

        vm.startPrank(usr2);
        tan.approve(address(vsTan), MAX_UINT);
        deal(address(tan), usr2, amount);

        vsTan.createLock(amount, false);

        vm.expectRevert(abi.encodeWithSelector(VsTAN.NothingToClaim.selector));
        vsTan.claimSimple(2, false);

        assertApproxEqAbs(usg.balanceOf(address(vsTan)), 0, 300_000);
        // assertApproxEqAbs(AddrClassicERC20.CVX.balanceOf(address(rewardAccumulator)), 0, 300_000);
    }
}
