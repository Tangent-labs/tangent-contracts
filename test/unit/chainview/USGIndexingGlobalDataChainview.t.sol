// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import {USGIndexingGlobalData, TVLAprs, MarketAPRInput, USGIndexingGlobalDataOut, USGContractsIn, KeeperIn} from "../../../src/chainview/USG/bot/USGIndexingGlobalData.cv.sol";
import {TokenAmount} from "../../../src/interfaces/internals/ICommonStruct.sol";
import {IPriceOracle} from "../../../src/interfaces/internals/USG/ICollateral.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract USGIndexingGlobalDataChainview is MarketDeploymentContext {
    ConvexCrvLPMarket public market1;
    ConvexCrvLPMarket public market2;
    ConvexFxnLPMarket public market3;
    ConvexCrvLPMarket public market4;

    MarketAPRInput[] marketsInput;
    address[] markets;
    function setUp() public {
        marketsInput.push(MarketAPRInput({marketAddress: address(deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD)), aprComputationType: 0}));
        marketsInput.push(MarketAPRInput({marketAddress: address(deployConvexCurveLPMarket(AddrCurveStableLP.WETH_frxETH)), aprComputationType: 0}));
        marketsInput.push(MarketAPRInput({marketAddress: address(deployConvexFxnLPMarket(AddrCurveStableLP.USDC_fxUSD)), aprComputationType: 1}));
        marketsInput.push(MarketAPRInput({marketAddress: address(deployConvexCurveLPMarket(AddrCurveStableLP.USDT_crvUSD)), aprComputationType: 0}));

        vm.startPrank(usr1);

        for (uint256 i; i < marketsInput.length; i++) {
            address marketAddress = marketsInput[i].marketAddress;
            MarketExternalActions market = MarketExternalActions(marketAddress);
            markets.push(marketAddress);
            IERC20 collatToken = market.collatToken();
            deal(address(collatToken), usr1, 100_000 ether);
            collatToken.approve(address(market), MAX_UINT);
            market.deposit(usr1, 100_000 ether, false);

            IERC20[] memory rewardTokens = rewardAccumulator.getRewardTokens(address(market));
            // Distribute rewards
            for (uint256 j; j < rewardTokens.length; j++) {
                deal(address(rewardTokens[j]), address(market), 1_000 ether);
            }
        }

        rewardAccumulator.processMultiRewards(markets, usr1, 3);
    }

    function test_USGIndexingGlobalData_Chainview() public {
        KeeperIn[] memory keepersIn = new KeeperIn[](2);
        keepersIn[0] = KeeperIn({keeper: address(pegKeeperUSG_USDC), lp: address(lpDeploymentContext.USGLPs("USG-USDC"))});
        keepersIn[1] = KeeperIn({keeper: address(pegKeeperUSG_wcrvUSD), lp: address(lpDeploymentContext.USGLPs("USG-wcrvUSD"))});

        try
            new USGIndexingGlobalData(
                marketsInput,
                USGContractsIn({rewardAccumulator: rewardAccumulator, irCalculator: irCalculator, usg: usg, sUSG: sUSG, usgOracle: USGOracle, _marketViewer: marketViewer}),
                keepersIn,
                Array.memoryAddress([address(wcrvUSD), address(wUSDE), address(wDOLA), address(wUSR)])
            )
        {} catch (bytes memory reason) {
            USGIndexingGlobalDataOut memory result = abi.decode(removeFirst4Bytes(reason), (USGIndexingGlobalDataOut));

            console.log("Convex projected APRs:");
            for (uint256 i; i < result.marketData.length; i++) {
                TVLAprs memory marketData = result.marketData[i];
                if (marketData.projectedAPR.totalSupplyUnderlying != 0) {
                    console.log("market");
                    console.logAddress(marketData.globalData.marketAddress);
                    console.log("convex total supply underlying", marketData.projectedAPR.totalSupplyUnderlying);
                    uint256 projectedAPR = _getProjectedConvexAPR(marketData);
                    console.log("convex apr 1e18", projectedAPR);
    

                    for (uint256 j; j < marketData.projectedAPR.streamingData.length; j++) {
                        TokenAmount memory reward = marketData.projectedAPR.streamingData[j];
                        console.log("reward token");
                        console.logAddress(address(reward.token));
                        console.log("yearly reward amount", reward.amount);
                    }
                }

                assertGt(result.marketData[i].currentAPR.length, 0);
                assertGt(result.marketData[i].currentAPR[0].amount, 0);
            }
        }
    }

    function _getProjectedConvexAPR(TVLAprs memory marketData) internal view returns (uint256) {
        uint256 tvlUsd = (marketData.projectedAPR.totalSupplyUnderlying * marketData.globalData.oraclePrice) / 1e18;
        if (tvlUsd == 0) return 0;

        uint256 yearlyRewardsUsd;
        for (uint256 i; i < marketData.projectedAPR.streamingData.length; i++) {
            TokenAmount memory reward = marketData.projectedAPR.streamingData[i];
            IPriceOracle oracle = oracles[reward.token];
            if (address(oracle) == address(0)) continue;

            uint256 rewardPrice = oracle.latestAnswer(true) * 10 ** (18 - oracle.decimals());
            uint8 rewardDecimals = IERC20Metadata(address(reward.token)).decimals();
            yearlyRewardsUsd += (reward.amount * rewardPrice) / 10 ** rewardDecimals;
        }

        return (yearlyRewardsUsd * 1e18) / tvlUsd;
    }
}
