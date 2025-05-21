// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract ProcessMultiRewards is MarketDeploymentContext {
    IERC20Metadata public collatToken1 = AddrPTPendle.eUSDe_29_05_25;
    MarketNoSociabilization public market1;

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

    function setUp() public {
        market1 = deployMarketNoSociabilisation(collatToken1);
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
            market.depositAndBorrow(10_000 ether, 5_000 ether, true);

            // Deposit rewards on the market contract,ready to be processed
            IERC20[] memory rewardTokens = rewardAccumulator.getRewardTokens(address(market));
            for (uint256 j; j < rewardTokens.length; j++) {
                IERC20 token = rewardTokens[j];
                deal(address(token), address(market), distributedAmounts[j]);
            }
        }
    }

    //
    function test_process_reward_multiple() external {
        vm.startPrank(usr1);

        uint256 totalCrvClaimed = 3 * distributedAmounts[0];
        uint256 totalCvxClaimed = 3 * distributedAmounts[1];
        uint256 totalFxnClaimed = distributedAmounts[2];

        uint256 harversterFeePercentage = (rewardAccumulator.getRCParams(address(market1))).harvestFeePercentage;

        uint256 harvestFeeCRV = ((totalCrvClaimed * harversterFeePercentage) / 100_000);
        uint256 harvestFeeCVX = ((totalCvxClaimed * harversterFeePercentage) / 100_000);
        uint256 harvestFeeFXN = ((totalFxnClaimed * harversterFeePercentage) / 100_000);

        verifyReceiveERC20(AddrClassicERC20.CRV, address(rewardAccumulator), totalCrvClaimed - harvestFeeCRV);
        verifyReceiveERC20(AddrClassicERC20.CVX, address(rewardAccumulator), totalCvxClaimed - harvestFeeCVX);
        verifyReceiveERC20(AddrClassicERC20.FXN, address(rewardAccumulator), totalFxnClaimed - harvestFeeFXN);

        verifyReceiveERC20(AddrClassicERC20.CRV, usr2, harvestFeeCRV);
        verifyReceiveERC20(AddrClassicERC20.CVX, usr2, harvestFeeCVX);
        verifyReceiveERC20(AddrClassicERC20.FXN, usr2, harvestFeeFXN);

        rewardAccumulator.processMultiRewards(Array.memoryAddress([address(market1), address(market2), address(market3), address(market4), address(market5)]), usr2, 3);

        uint256 lastRewardCutPercentage = rewardAccumulator.lastRewardCuts(address(market1));

        assertEq(((totalCrvClaimed - harvestFeeCRV) * lastRewardCutPercentage) / 100_000, rewardAccumulator.cutFeeForToken(AddrClassicERC20.CRV));
        assertEq(((totalCvxClaimed - harvestFeeCVX) * lastRewardCutPercentage) / 100_000, rewardAccumulator.cutFeeForToken(AddrClassicERC20.CVX));
        assertEq(((totalFxnClaimed - harvestFeeFXN) * lastRewardCutPercentage) / 100_000, rewardAccumulator.cutFeeForToken(AddrClassicERC20.FXN));

        assertERC20Tracking();
    }
}
