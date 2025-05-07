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

        vm.stopPrank();
    }
    function test_claimMultiple_success() external {
        // Process the rewards when period is finished
        vm.startPrank(usr1);

        // Process the rewards when period is not finished, we pass in the else
        skip(6 days);

        uint256 totalTanLocked = rsTan.totalSupplyRsTan();

        uint256 expectedTgUSDClaimable = (6 days * tgUSDToDistribute * (amountLocked1 + 2 * amountLocked2)) / (totalTanLocked * 1 weeks);

        verifyLostDeltaRelERC20(tgUSD, address(rsTan), expectedTgUSDClaimable, 1e5, "TgUSD claimed, removed from rsTan");
        verifyReceiveDeltaRelERC20(tgUSD, usr1, expectedTgUSDClaimable, 1e5, "TgUSD claimed and transfered to usr");

        rsTan.claimMultiple(Array.memoryUint256([uint256(3), uint256(1), uint256(2)]), false);

        assertERC20Tracking();

        vm.stopPrank();

        skip(1 days);

        vm.startPrank(usr2);

        expectedTgUSDClaimable = (tgUSDToDistribute * (amountLocked1 + amountLocked2)) / totalTanLocked;

        verifyLostDeltaRelERC20(tgUSD, address(rsTan), expectedTgUSDClaimable, 1e5, "TgUSD claimed, removed from rsTan");
        verifyReceiveDeltaRelERC20(tgUSD, usr2, expectedTgUSDClaimable, 1e5, "TgUSD claimed and transfered to usr");

        rsTan.claimMultiple(Array.memoryUint256([uint256(4), uint256(5)]), false);

        assertERC20Tracking();

        vm.stopPrank();

        vm.startPrank(usr1);
        expectedTgUSDClaimable = (tgUSDToDistribute * (amountLocked1 + 2 * amountLocked2)) / (totalTanLocked * 7);

        verifyLostDeltaRelERC20(tgUSD, address(rsTan), expectedTgUSDClaimable, 1e5, "TgUSD claimed, removed from rsTan");
        verifyReceiveDeltaRelERC20(tgUSD, usr1, expectedTgUSDClaimable, 1e5, "TgUSD claimed and transfered to usr");
        rsTan.claimMultiple(Array.memoryUint256([uint256(3), uint256(1), uint256(2)]), false);
        assertERC20Tracking();

        vm.stopPrank();
    }
}
