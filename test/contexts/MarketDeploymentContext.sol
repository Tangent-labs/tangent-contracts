// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./MarketInitParams.sol";

import "../../src/interfaces/internals/USG/IMarketCore.sol";
import "../../src/interfaces/internals/USG/IIRCalculator.sol";

contract MarketDeploymentContext is MarketInitParams {
    function deployConvexCurveLPMarket(IERC20Metadata collat) public returns (ConvexCrvLPMarket) {
        ParamsInitConvexCurveLPMarket memory initP = cvxCurveLPMaps[address(collat)];

        vm.startPrank(owner);

        ConvexCrvLPMarket convexMarket = ConvexCrvLPMarket(
            marketCreator.createConvexCrvMarket(getMarketInit(initP.marketInit, collat), initP.pid, getBaseIRParamsHEC(), getBaseRCParams())
        );

        assertEq(address(convexMarket.collatOracle()), address(oracles[collat]), "Collat oracle address setup");

        verifyParams_and_dealCollat(initP.marketInit.collat);

        IERC20[] memory curveConvexRewards = new IERC20[](2);
        curveConvexRewards[0] = AddrClassicERC20.CRV;
        curveConvexRewards[1] = AddrClassicERC20.CVX;
        rewardAccumulator.addNewRewards(address(convexMarket), curveConvexRewards);

        vm.stopPrank();

        labeliser.labeliseNewConvexCrvMarket(address(collat), collat.symbol(), address(convexMarket), address(initP.cvxRewardToken));

        return convexMarket;
    }

    function deployConvexFxnLPMarket(IERC20Metadata collat) public returns (ConvexFxnLPMarket) {
        ParamsInitConvexFxnLPMarket memory initP = cvxFxnLPMaps[address(collat)];

        vm.startPrank(owner);

        ConvexFxnLPMarket convexMarket = ConvexFxnLPMarket(
            marketCreator.createConvexFxnMarket(getMarketInit(initP.marketInit, collat), initP.pid, getBaseIRParamsLEC(), getBaseRCParams())
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

    function deployBasicERC20Market(IERC20Metadata collat) public returns (BasicERC20Market) {
        MarketInitSimplified memory marketInit = basicERC20Maps[address(collat)];
        vm.startPrank(owner);

        BasicERC20Market marketBasicERC20 = BasicERC20Market(marketCreator.createBasicERC20Market(getMarketInit(marketInit, collat), getBaseIRParamsLEC(), getBaseRCParams()));

        verifyParams_and_dealCollat(marketInit.collat);

        vm.stopPrank();

        return marketBasicERC20;
    }

    function deployCurveGaugeMarket(IERC20Metadata collat, IERC20[] memory rewardTokens) public returns (CurveGaugeMarket) {
        ParamsInitCurveGaugeMarket memory initP = curveGaugeMaps[address(collat)];
        require(address(initP.marketInit.collat) != address(0), "Market not setup");
        vm.startPrank(owner);

        CurveGaugeMarket gaugeMarket = CurveGaugeMarket(
            marketCreator.createCurveGaugeMarket(getMarketInit(initP.marketInit, collat), initP.gaugeToken, getBaseIRParamsHEC(), getBaseRCParams())
        );

        assertEq(address(gaugeMarket.collatOracle()), address(oracles[collat]), "Collat oracle address setup");

        rewardAccumulator.addNewRewards(address(gaugeMarket), rewardTokens);

        // Deal the lp token not the gauge token
        IERC20Metadata lp = initP.marketInit.collat;
        verifyParams_and_dealCollat(lp);
        _approve_and_stake_curve_gauge(lp, initP.gaugeToken);

        vm.stopPrank();

        labeliser.labeliseNewCurveGaugeMarket(address(collat), collat.symbol(), address(gaugeMarket), address(initP.gaugeToken));

        return gaugeMarket;
    }

    function deployStakeDaoVaultV2Market(IERC20Metadata collat) public returns (StakeDaoVaultV2Market) {
        ParamsInitStakeDaoVaultV2Market memory initP = stakeDaoVaultV2Maps[address(collat)];
        require(address(initP.marketInit.collat) != address(0), "Market not setup");
        vm.startPrank(owner);

        StakeDaoVaultV2Market vaultMarket = StakeDaoVaultV2Market(
            marketCreator.createStakeDaoVaultV2Market(getMarketInit(initP.marketInit, collat), initP.vaultToken, getBaseIRParamsHEC(), getBaseRCParams())
        );

        assertEq(address(vaultMarket.collatOracle()), address(oracles[collat]), "Collat oracle address setup");

        IERC20[] memory rewards = new IERC20[](1);
        rewards[0] = AddrClassicERC20.CRV;
        rewardAccumulator.addNewRewards(address(vaultMarket), rewards);

        // Deal the lp token not the gauge token
        IERC20Metadata lp = initP.marketInit.collat;
        verifyParams_and_dealCollat(lp);
        _approve_and_stake_stakeDao_vault(lp, initP.vaultToken);

        vm.stopPrank();

        labeliser.labeliseNewStakeDaoVaultV2Market(address(collat), collat.symbol(), address(vaultMarket), address(initP.vaultToken));

        return vaultMarket;
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

    function _approve_and_stake_curve_gauge(IERC20Metadata lp, IGauge gauge) internal {
        address[4] memory users = [usr1, usr2, usr3, usr4];
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            vm.startPrank(user);
            lp.approve(address(gauge), MAX_UINT);
            gauge.deposit(100_000 ether);
            vm.stopPrank();
        }
    }

    function _approve_and_stake_stakeDao_vault(IERC20Metadata lp, IStakeDaoVaultV2 vault) internal {
        address[4] memory users = [usr1, usr2, usr3, usr4];
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            vm.startPrank(user);
            lp.approve(address(vault), MAX_UINT);
            vault.deposit(100_000 ether, user);
            vm.stopPrank();
        }
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
