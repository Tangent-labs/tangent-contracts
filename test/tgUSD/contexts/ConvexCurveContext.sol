// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./MarketInitParams.sol";

import "../../../src/interfaces/internals/tgUSD/IMarketCore.sol";
import "../../../src/interfaces/internals/tgUSD/IIRCalculator.sol";
contract ConvexCurveContext is MarketInitParams {
    function deployConvexCurveLPMarket(IERC20Metadata collat) public returns (ConvexCrvLPMarket) {
        ParamsInitConvexCurveLPMarket memory initP = cvxCurveLPMaps[address(collat)];

        assertTrue(address(initP.marketInit.collat) != address(0), "No init params for LP");
        assertTrue(address(oracles[collat]) != address(0), "Oracle not setup");

        vm.startPrank(owner);

        ConvexCrvLPMarket convexMarket = ConvexCrvLPMarket(
            marketCreator.createConvexCrvMarket(
                MarketInit({
                    collatToken: initP.marketInit.collat,
                    collatOracle: oracles[collat],
                    maxLTV: initP.marketInit.maxLTV,
                    maxMarketDebt: initP.marketInit.maxMarketDebt,
                    liquidationThreshold: initP.marketInit.liquidationThreshold,
                    minimumLoan: initP.marketInit.minimumLoan,
                    _rewardTokens: initP.marketInit._rewardTokens
                }),
                initP.cvxRewardToken,
                initP.pid,
                initP.socFeePercentage,
                getBaseIRParams(),
                getBaseRCParams()
            )
        );

        assertEq(address(convexMarket.collatOracle()), address(oracles[collat]), "Collat oracle address setup");

        verifyParams_and_dealCollat(initP.marketInit.collat);

        IERC20[] memory curveConvexRewards = new IERC20[](2);
        curveConvexRewards[0] = AddrClassicERC20.TOKEN_CRV;
        curveConvexRewards[1] = AddrClassicERC20.TOKEN_CVX;
        rewardAccumulator.addNewRewards(address(convexMarket), curveConvexRewards);

        vm.stopPrank();

        labeliser.labeliseNewConvexCrvMarket(address(collat), collat.symbol(), address(convexMarket), address(initP.cvxRewardToken));

        return convexMarket;
    }

    function deployConvexFxnLPMarket(IERC20Metadata collat) public returns (ConvexFxnLPMarket) {
        ParamsInitConvexFxnLPMarket memory initP = cvxFxnLPMaps[address(collat)];

        assertTrue(address(initP.marketInit.collat) != address(0), "No init params for LP");
        assertTrue(address(oracles[collat]) != address(0), "Oracle not setup");

        vm.startPrank(owner);

        ConvexFxnLPMarket convexMarket = ConvexFxnLPMarket(
            marketCreator.createConvexFxnMarket(
                MarketInit({
                    collatToken: initP.marketInit.collat,
                    collatOracle: oracles[collat],
                    maxLTV: initP.marketInit.maxLTV,
                    maxMarketDebt: initP.marketInit.maxMarketDebt,
                    liquidationThreshold: initP.marketInit.liquidationThreshold,
                    minimumLoan: initP.marketInit.minimumLoan,
                    _rewardTokens: initP.marketInit._rewardTokens
                }),
                initP.pid,
                initP.socFeePercentage,
                getBaseIRParams(),
                getBaseRCParams()
            )
        );

        verifyParams_and_dealCollat(initP.marketInit.collat);

        IERC20[] memory curveConvexRewards = new IERC20[](3);
        curveConvexRewards[0] = AddrClassicERC20.TOKEN_CRV;
        curveConvexRewards[1] = AddrClassicERC20.TOKEN_CVX;
        curveConvexRewards[2] = AddrClassicERC20.TOKEN_FXN;
        rewardAccumulator.addNewRewards(address(convexMarket), curveConvexRewards);
        vm.stopPrank();

        labeliser.labeliseNewConvexFxnMarket(address(collat), collat.symbol(), address(convexMarket), address(convexMarket.stakingProxyVault()));

        return convexMarket;
    }

    function giveCollateralToUsers(IERC20Metadata collat) public {
        deal(address(collat), usr1, 1_000_000_000 * 10 ** 18);
        deal(address(collat), usr2, 1_000_000_000 * 10 ** 18);
        deal(address(collat), usr3, 1_000_000_000 * 10 ** 18);
        deal(address(collat), usr4, 1_000_000_000 * 10 ** 18);
    }

    function verifyParams_and_dealCollat(IERC20Metadata collat) internal {
        assertTrue(address(collat) != address(0), "No init params for LP");
        assertTrue(address(oracles[collat]) != address(0), "Oracle not setup");

        giveCollateralToUsers(collat);
    }

    function getBaseIRParams() public pure returns (IRParams memory) {
        return IRParams({isHEC: true, rMin: 4_000, rMax: 400_000, pMin: 980_000, pMax: 995_000, pInf: 990_000, a1: 2_000, a2: 2_000, k: 250});
    }

    function getBaseRCParams() public pure returns (RCParams memory) {
        return
            RCParams({
                harvestFeePercentage: 1_000,
                startCutPercentage: 50_000,
                endCutPercentage: 100_000,
                stepAmount: 4,
                startCutPrice: 995000000000000000,
                endCutPrice: 900000000000000000
            });
    }
}
