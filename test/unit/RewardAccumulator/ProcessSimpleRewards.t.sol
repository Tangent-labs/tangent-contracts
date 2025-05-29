// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
import "../../handler/Curve/HLPManipulator.sol";

contract ProcessSimpleRewards is MarketDeploymentContext {
    HLPManipulator public lpManipulator;

    IERC20Metadata public collatToken = AddrCurveStableLP.USDC_fxUSD;
    ConvexFxnLPMarket public market;

    uint256[3] distributedAmounts = [uint256(10_000 ether), uint256(2_000 ether), uint256(12_000 ether)];
    uint256[3] processableAmountsExpected;

    function setUp() public {
        // Depeg USG
        lpManipulator = new HLPManipulator(usr2);
        lpManipulator.dumpCrvPool(lpDeploymentContext.tgUSDLPs("tgUSD-USDC"), 1, 0, 470_000 ether);

        // Deploy several markets
        market = deployConvexFxnLPMarket(collatToken);

        // Perform staking
        vm.startPrank(usr1);

        // Perform staking
        deal(address(collatToken), usr1, 100_000 ether);
        collatToken.approve(address(market), MAX_UINT);
        market.depositAndBorrow(10_000 ether, 5_000 ether, true);

        // Deposit rewards on the market contract,ready to be processed
        IERC20[] memory rewardTokens = rewardAccumulator.getRewardTokens(address(market));
        for (uint256 j; j < rewardTokens.length; j++) {
            IERC20 token = rewardTokens[j];
            deal(address(token), address(market), distributedAmounts[j]);
        }

        // Skip 1 day to change USG oracle price
        skip(1 days);

        // Claim the residual rewards on Convex to be able to determine exactly the amount distributed
        market.stakingProxyVault().getReward();

        processableAmountsExpected = [
            AddrClassicERC20.CRV.balanceOf(address(market)),
            AddrClassicERC20.CVX.balanceOf(address(market)),
            AddrClassicERC20.FXN.balanceOf(address(market))
        ];
    }

    function test_process_reward_simple() external {
        vm.startPrank(usr1);

        uint256 harversterFeePercentage = (rewardAccumulator.getRCParams(address(market))).harvestFeePercentage;

        uint256[3] memory processedR;

        for (uint256 i = 0; i < processableAmountsExpected.length; i++) {
            uint256 expectedProcessable = processableAmountsExpected[i];
            uint256 harvesterFee = (expectedProcessable * harversterFeePercentage) / 100_000;
            IERC20 rewardToken = rewardAccumulator.rewardTokens(address(market), i);
            processedR[i] = expectedProcessable - harvesterFee;

            verifyReceiveERC20(rewardToken, address(rewardAccumulator), expectedProcessable - harvesterFee);
            verifyReceiveERC20(rewardToken, usr2, harvesterFee);
        }

        uint256 lastRewardCutPercentage = rewardAccumulator.lastRewardCuts(address(market));

        rewardAccumulator.processMultiRewards(Array.memoryAddress([address(market)]), usr2, 3);

        assertLt(lastRewardCutPercentage, rewardAccumulator.lastRewardCuts(address(market)));

        for (uint256 i; i < processedR.length; i++) {
            IERC20 rewardToken = rewardAccumulator.rewardTokens(address(market), i);
            assertEq((processedR[i] * lastRewardCutPercentage) / 100_000, rewardAccumulator.cutFeeForToken(rewardToken));
        }

        assertERC20Tracking();
    }

    function test_process_reward_without_reward_cut() external {
        vm.stopPrank();
        vm.prank(owner);

        rewardAccumulator.updateRCParams(
            address(market),
            RCParams({harvestFeePercentage: 0, stepAmount: 0, startCutPercentage: 0, endCutPercentage: 0, startCutPrice: 0, endCutPrice: 0})
        );

        // Deposit rewards on the market contract,ready to be processed
        IERC20[] memory rewardTokens = rewardAccumulator.getRewardTokens(address(market));
        for (uint256 j; j < rewardTokens.length; j++) {
            IERC20 token = rewardTokens[j];
            deal(address(token), address(market), distributedAmounts[j]);
        }

        skip(7 days);

        // Claim the residual rewards on Convex to be able to determine exactly the amount distributed
        market.stakingProxyVault().getReward();

        for (uint256 i; i < rewardTokens.length; i++) {
            IERC20 token = rewardTokens[i];
            distributedAmounts[i] = token.balanceOf(address(market));
        }

        vm.startPrank(usr1);

        uint256 harversterFeePercentage = (rewardAccumulator.getRCParams(address(market))).harvestFeePercentage;

        uint256[3] memory processedR;

        for (uint256 i = 0; i < processableAmountsExpected.length; i++) {
            uint256 expectedProcessable = distributedAmounts[i];
            uint256 harvesterFee = (expectedProcessable * harversterFeePercentage) / 100_000;
            IERC20 rewardToken = rewardAccumulator.rewardTokens(address(market), i);
            processedR[i] = expectedProcessable - harvesterFee;

            verifyReceiveERC20(rewardToken, address(rewardAccumulator), expectedProcessable - harvesterFee);
            verifyReceiveERC20(rewardToken, usr2, harvesterFee);
        }

        rewardAccumulator.processRewards(address(market), usr2);

        assertEq(0, rewardAccumulator.lastRewardCuts(address(market)));

        assertERC20Tracking();
    }
}
