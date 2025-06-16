// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./MarketInitParams.sol";

import "../../src/interfaces/internals/tgUSD/IMarketCore.sol";
import "../../src/interfaces/internals/tgUSD/IIRCalculator.sol";
contract MarketDeploymentContext is MarketInitParams {
    function deployConvexCurveLPMarket(IERC20Metadata collat, bool isConvexLinked) public returns (ConvexCrvLPMarket) {
        ParamsInitConvexCurveLPMarket memory initP = cvxCurveLPMaps[address(collat)];

        vm.startPrank(owner);

        ConvexCrvLPMarket convexMarket = ConvexCrvLPMarket(
            marketCreator.createConvexCrvMarket(
                getMarketInit(initP.marketInit, collat),
                isConvexLinked ? initP.cvxRewardToken : ICvxRewardToken(address(0)),
                isConvexLinked ? initP.pid : 0,
                initP.socFeePercentage,
                getBaseIRParamsHEC(),
                getBaseRCParams()
            )
        );

        assertEq(address(convexMarket.collatOracle()), address(oracles[collat]), "Collat oracle address setup");

        verifyParams_and_dealCollat(initP.marketInit.collat);

        if (isConvexLinked) {
            IERC20[] memory curveConvexRewards = new IERC20[](2);
            curveConvexRewards[0] = AddrClassicERC20.CRV;
            curveConvexRewards[1] = AddrClassicERC20.CVX;
            rewardAccumulator.addNewRewards(address(convexMarket), curveConvexRewards);
        }

        vm.stopPrank();

        labeliser.labeliseNewConvexCrvMarket(address(collat), collat.symbol(), address(convexMarket), address(initP.cvxRewardToken));

        return convexMarket;
    }

    function deployConvexFxnLPMarket(IERC20Metadata collat) public returns (ConvexFxnLPMarket) {
        ParamsInitConvexFxnLPMarket memory initP = cvxFxnLPMaps[address(collat)];

        vm.startPrank(owner);

        ConvexFxnLPMarket convexMarket = ConvexFxnLPMarket(
            marketCreator.createConvexFxnMarket(getMarketInit(initP.marketInit, collat), initP.pid, initP.socFeePercentage, getBaseIRParamsLEC(), getBaseRCParams())
        );

        verifyParams_and_dealCollat(initP.marketInit.collat);

        IERC20[] memory curveConvexRewards = new IERC20[](3);
        curveConvexRewards[0] = AddrClassicERC20.CRV;
        curveConvexRewards[1] = AddrClassicERC20.CVX;
        curveConvexRewards[2] = AddrClassicERC20.FXN;
        rewardAccumulator.addNewRewards(address(convexMarket), curveConvexRewards);
        vm.stopPrank();

        labeliser.labeliseNewConvexFxnMarket(address(collat), collat.symbol(), address(convexMarket), address(convexMarket.stakingProxyVault()));

        return convexMarket;
    }

    function deployMarketNoSociabilisation(IERC20Metadata collat) public returns (MarketNoSociabilization) {
        MarketInitSimplified memory marketInit = noSociabilizationMaps[address(collat)];
        vm.startPrank(owner);

        MarketNoSociabilization marketNoSoc = MarketNoSociabilization(
            marketCreator.createNoSociabilizationMarket(getMarketInit(marketInit, collat), getBaseIRParamsLEC(), getBaseRCParams())
        );

        verifyParams_and_dealCollat(marketInit.collat);

        vm.stopPrank();

        // labeliser.labeliseNewConvexFxnMarket(address(collat), collat.symbol(), address(marketNoSoc), address(convexMarket.stakingProxyVault()));

        return marketNoSoc;
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

    function getMarketInit(MarketInitSimplified memory init, IERC20 collat) public view returns (MarketInit memory) {
        return
            MarketInit({
                name: "",
                collatToken: init.collat,
                collatOracle: oracles[collat],
                maxLTV: init.maxLTV,
                maxMarketDebt: init.maxMarketDebt,
                liquidationThreshold: init.liquidationThreshold,
                liquidationFee: init.liquidationFee,
                minimumLoan: init.minimumLoan
            });
    }

    function getBaseIRParamsHEC() public pure returns (IRParams memory) {
        return IRParams({isHEC: true, rMin: 4_000, rMax: 400_000, pMin: 980_000, pMax: 995_000, pInf: 990_000, a1: 2_000, a2: 2_000, k: 250});
    }

    function getBaseIRParamsLEC() public pure returns (IRParams memory) {
        return IRParams({isHEC: false, rMin: 6_000, rMax: 400_000, pMin: 985_000, pMax: 995_000, pInf: 995_000, a1: 2_500, a2: 3_500, k: 250});
    }

    function getBaseRCParams() public pure returns (RCParams memory) {
        return RCParams({harvestFeePercentage: 1_000, startCutPercentage: 50_000, endCutPercentage: 100_000, stepAmount: 4, startCutPrice: 995_000, endCutPrice: 900_000});
    }
}
