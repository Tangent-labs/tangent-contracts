// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import {MarketCurrentAPR, TVLAprs, MarketAPRInput} from "../../../src/chainview/tgUSD/apr/MarketCurrentAPR.cv.sol";

contract MarketCurrentAPRChainview is MarketDeploymentContext {
    ConvexCrvLPMarket public market1;
    ConvexCrvLPMarket public market2;
    ConvexFxnLPMarket public market3;
    ConvexCrvLPMarket public market4;

    MarketAPRInput[] marketsInput;
    address[] markets;
    function setUp() public {
        marketsInput.push(MarketAPRInput({marketAddress: address(deployConvexCurveLPMarket(AddrCurveStableLP.USDC_crvUSD, true)), aprComputationType: 0}));
        marketsInput.push(MarketAPRInput({marketAddress: address(deployConvexCurveLPMarket(AddrCurveStableLP.WETH_frxETH, true)), aprComputationType: 0}));
        marketsInput.push(MarketAPRInput({marketAddress: address(deployConvexFxnLPMarket(AddrCurveStableLP.USDC_fxUSD)), aprComputationType: 1}));
        marketsInput.push(MarketAPRInput({marketAddress: address(deployConvexCurveLPMarket(AddrCurveStableLP.USDT_crvUSD, true)), aprComputationType: 0}));

        vm.startPrank(usr1);

        for (uint256 i; i < marketsInput.length; i++) {
            address marketAddress = marketsInput[i].marketAddress;
            MarketExternalActions market = MarketExternalActions(marketAddress);
            markets.push(marketAddress);
            IERC20 collatToken = market.collatToken();
            deal(address(collatToken), usr1, 100_000 ether);
            collatToken.approve(address(market), MAX_UINT);
            market.deposit(usr1, 100_000 ether, true);

            IERC20[] memory rewardTokens = rewardAccumulator.getRewardTokens(address(market));
            // Distribute rewards
            for (uint256 j; j < rewardTokens.length; j++) {
                deal(address(rewardTokens[j]), address(market), 1_000 ether);
            }
        }

        rewardAccumulator.processMultiRewards(markets, usr1, 3);
    }

    function test_MarketCurrentAPR_Chainview() public {
        try new MarketCurrentAPR(marketsInput, rewardAccumulator, irCalculator) {} catch (bytes memory reason) {
            TVLAprs[] memory result = abi.decode(removeFirst4Bytes(reason), (TVLAprs[]));

            for (uint256 i; i < result.length; i++) {
                assertGt(result[i].currentAPR[0].amountPerYear, 0);
            }
        }
    }
}
