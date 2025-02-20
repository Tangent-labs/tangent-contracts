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

        vm.stopPrank();

        assertEq(address(convexMarket.collatOracle()), address(oracles[collat]), "Collat oracle address setup");

        verifyParams_and_dealCollat(initP.marketInit.collat);

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

        vm.stopPrank();
        verifyParams_and_dealCollat(initP.marketInit.collat);

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
        return IRParams({rMin: 4_000, rMax: 400_000, pMin: 9_800, pMax: 10_000, pInf: 0, a1: 2, a2: 2, k: 0});
    }

    function getBaseRCParams() public pure returns (RCParams memory) {
        return RCParams({startCutPercentage: 50_000, endCutPercentage: 100_000, stepAmount: 4, startCutPrice: 995000000000000000, endCutPrice: 900000000000000000});
    }
}
