// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
import "../../handler/Curve/HLPManipulator.sol";

contract ProcessMultiRewards is MarketDeploymentContext {
    HLPManipulator public lpManipulator;

    IERC20Metadata public collatToken1 = AddrPTPendle.eUSDe_29_05_25;
    BasicERC20Market public market1;

    IERC20Metadata public collatToken2 = AddrCurveStableLP.USDC_crvUSD;
    ConvexCrvLPMarket public market2;

    IERC20Metadata public collatToken3 = AddrCryptoSwapLP.USDC_WBTC_ETH;
    ConvexCrvLPMarket public market3;

    IERC20Metadata public collatToken4 = AddrCurveStableLP.USDC_fxUSD;
    ConvexFxnLPMarket public market4;

    IERC20Metadata public collatToken5 = AddrCurveStableLP.sUSDS_USDT;
    ConvexCrvLPMarket public market5;

    MarketExternalActions[] markets;

    uint256[3] distributedAmounts = [uint256(10_000 ether), uint256(2_000 ether), uint256(1_000 ether)];
    uint256[3] processableAmountsExpected;

    function setUp() public {
        // Depeg USG
        lpManipulator = new HLPManipulator(usr2);
        lpManipulator.dumpCrvPool(lpDeploymentContext.USGLPs("USG-USDC"), 1, 0, 470_000 ether);

        // Deploy several markets
        market1 = deployBasicERC20Market(collatToken1);
        market2 = deployConvexCurveLPMarket(collatToken2, true);
        market3 = deployConvexCurveLPMarket(collatToken3, true);
        market4 = deployConvexFxnLPMarket(collatToken4);
        market5 = deployConvexCurveLPMarket(collatToken5, false);

        markets.push(market1);
        markets.push(market2);
        markets.push(market3);
        markets.push(market4);
        markets.push(market5);

        // Perform staking
        vm.startPrank(usr1);
        for (uint256 i; i < markets.length; i++) {
            MarketExternalActions market = markets[i];
            IERC20 collatToken = market.collatToken();

            // Perform staking
            deal(address(collatToken), usr1, 100_000 ether);
            collatToken.approve(address(market), MAX_UINT);
            market.depositAndBorrow(10_000 ether, 5_000 ether);

            // Deposit rewards on the market contract,ready to be processed
            IERC20[] memory rewardTokens = rewardAccumulator.getRewardTokens(address(market));
            for (uint256 j; j < rewardTokens.length; j++) {
                IERC20 token = rewardTokens[j];
                deal(address(token), address(market), distributedAmounts[j]);
            }
        }

        // Skip 1 day to change USG oracle price
        skip(1 days);

        // Claim the residual rewards on Convex to be able to determine exactly the amount distributed
        market2.cvxRewardToken().getReward(address(market2), true);
        market3.cvxRewardToken().getReward(address(market3), true);
        market4.stakingProxyVault().getReward();

        processableAmountsExpected = [
            AddrClassicERC20.CRV.balanceOf(address(market2)) + AddrClassicERC20.CRV.balanceOf(address(market3)) + AddrClassicERC20.CRV.balanceOf(address(market4)),
            AddrClassicERC20.CVX.balanceOf(address(market2)) + AddrClassicERC20.CVX.balanceOf(address(market3)) + AddrClassicERC20.CVX.balanceOf(address(market4)),
            AddrClassicERC20.FXN.balanceOf(address(market4))
        ];
    }

    function test_process_reward_multiple() external {
        vm.startPrank(usr1);

        uint256 harversterFeePercentage = (rewardAccumulator.getRCParams(address(market1))).harvestFeePercentage;

        uint256[3] memory processedR;

        for (uint256 i = 0; i < processableAmountsExpected.length; i++) {
            uint256 expectedProcessable = processableAmountsExpected[i];
            uint256 harvesterFee = (expectedProcessable * harversterFeePercentage) / 100_000;
            IERC20 rewardToken = rewardAccumulator.rewardTokens(address(market4), i);
            processedR[i] = expectedProcessable - harvesterFee;

            verifyReceiveDeltaAbsERC20(rewardToken, address(rewardAccumulator), expectedProcessable - harvesterFee, 1);
            verifyReceiveDeltaAbsERC20(rewardToken, usr2, harvesterFee, 1);
        }

        uint256 lastRewardCutPercentage = rewardAccumulator.lastRewardCuts(address(market1));

        rewardAccumulator.processMultiRewards(Array.memoryAddress([address(market1), address(market2), address(market3), address(market4), address(market5)]), usr2, 3);

        assertLt(lastRewardCutPercentage, rewardAccumulator.lastRewardCuts(address(market1)));

        for (uint256 i; i < processedR.length; i++) {
            IERC20 rewardToken = rewardAccumulator.rewardTokens(address(market4), i);
            assertApproxEqAbs((processedR[i] * lastRewardCutPercentage) / 100_000, rewardAccumulator.cutFeeForToken(rewardToken), 1);
        }

        assertERC20Tracking();
    }

    function test_processMultiRewards_fails_if_one_market_in_params_is_not_a_market() external {
        address[] memory _markets = Array.memoryAddress([address(market1), address(market2), address(market3), address(usr2), address(market5)]);
        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.NotAMarketRewards.selector));
        rewardAccumulator.processMultiRewards(_markets, usr2, 3);
    }

    function test_processMultiRewards_fails_if_the_amount_of_erc20_passed_is_too_small() external {
        address[] memory _markets = Array.memoryAddress([address(market1), address(market2), address(market3), address(market4), address(market5)]);
        vm.expectRevert();
        rewardAccumulator.processMultiRewards(_markets, usr2, 2);
    }

    function test_processMultiRewards_fails_if_the_amount_of_erc20_passed_is_too_big() external {
        address[] memory _markets = Array.memoryAddress([address(market1), address(market2), address(market3), address(market4), address(market5)]);
        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.IncorrectRewardLength.selector, 4, 3));
        rewardAccumulator.processMultiRewards(_markets, usr2, 4);
    }
}
