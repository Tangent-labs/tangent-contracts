// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract AddNewRewardRewardAcc is MarketDeploymentContext {
    IERC20Metadata public collatToken = AddrCryptoSwapLP.USDC_WBTC_ETH;
    ConvexCrvLPMarket public market;

    function setUp() public {
        market = deployConvexCurveLPMarket(collatToken, true);
    }

    function test_addNewRewards_success() external {
        vm.startPrank(owner);
        IERC20[] memory tokensToAdd = new IERC20[](2);
        tokensToAdd[0] = AddrClassicERC20.DOLA;
        tokensToAdd[1] = AddrClassicERC20.USDT;

        rewardAccumulator.addNewRewards(address(market), tokensToAdd);

        IERC20[] memory tokens = rewardAccumulator.getRewardTokens(address(market));
        assertEq(tokens.length, 4);
        assertEq(address(tokens[2]), address(AddrClassicERC20.DOLA));
        assertEq(address(tokens[3]), address(AddrClassicERC20.USDT));
    }

    uint256[] totalProcessed;

    function test_addNewRewards_after_creation() external {
        uint256 amountStaked = 100 ether;
        uint256 borrowed = 20_000 ether;
        deal(address(collatToken), usr1, amountStaked * 2);
        deal(address(collatToken), usr2, amountStaked * 2);

        vm.startPrank(usr1);
        collatToken.approve(address(market), MAX_UINT);
        market.depositAndBorrow(amountStaked * 2, borrowed, true);

        vm.startPrank(usr2);
        collatToken.approve(address(market), MAX_UINT);
        market.depositAndBorrow(amountStaked, borrowed, true);

        vm.startPrank(owner);
        uint256 distributed = 10_000 ether;
        for (uint256 i; i < rewardAccumulator.getRewardTokens(address(market)).length; i++) {
            IERC20 token = rewardAccumulator.rewardTokens(address(market), i);
            deal(address(token), address(market), distributed);
        }

        rewardAccumulator.processRewards(address(market), usr1);

        totalProcessed.push(AddrClassicERC20.CRV.balanceOf(address(rewardAccumulator)) - rewardAccumulator.cutFeeForToken(AddrClassicERC20.CRV));
        totalProcessed.push(AddrClassicERC20.CVX.balanceOf(address(rewardAccumulator)) - rewardAccumulator.cutFeeForToken(AddrClassicERC20.CVX));
        totalProcessed.push(AddrClassicERC20.DOLA.balanceOf(address(rewardAccumulator)) - rewardAccumulator.cutFeeForToken(AddrClassicERC20.DOLA));

        skip(3.5 days);

        vm.startPrank(owner);
        IERC20[] memory tokensToAdd = new IERC20[](1);
        tokensToAdd[0] = AddrClassicERC20.DOLA;

        rewardAccumulator.addNewRewards(address(market), tokensToAdd);

        deal(address(AddrClassicERC20.DOLA), address(market), distributed);

        rewardAccumulator.processRewards(address(market), usr1);

        vm.stopPrank();

        skip(3.5 days);

        // Claim USR1

        verifyReceiveERC20(AddrClassicERC20.CRV, usr1, 100 ether);
        verifyReceiveERC20(AddrClassicERC20.CVX, usr1, 100 ether);
        verifyReceiveERC20(AddrClassicERC20.DOLA, usr1, 100 ether);

        vm.prank(usr1);
        rewardAccumulator.claimSimple(address(market));

        assertERC20Tracking();

        // Claim USR2
        vm.prank(usr2);
        rewardAccumulator.claimSimple(address(market));
    }
}
