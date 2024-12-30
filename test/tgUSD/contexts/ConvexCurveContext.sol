// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./MarketInitParams.sol";

import "../../../src/tgUSD/Market/Convex/ConvexCrvLPMarket.sol";
import "../../../src/tgUSD/Market/Convex/ConvexFxnLPMarket.sol";

import "../handler/Features/HProcessRewards.sol";

import "../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
import "../handler/Features/ConvexCrv/HWithdrawConvexCrvLP.sol";

import "../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../handler/Features/ConvexFxn/HWithdrawConvexFxnLP.sol";

import "../handler/Curve/HLpManipulator.sol";
import "../../../src/interfaces/internals/tgUSD/IMarketCore.sol";

contract ConvexCurveContext is MarketInitParams {
    function deployConvexCurveLPMarket(IERC20Metadata collat) public returns (ConvexCrvLPMarket) {
        ParamsInitConvexCurveLPMarket memory initP = cvxCurveLPMaps[address(collat)];

        assertTrue(address(initP.marketInit.collat) != address(0), "No init params for LP");
        assertTrue(address(oracles[collat]) != address(0), "Oracle not setup");

        /// Initialize reward tokens for the market
        ConvexCrvLPMarket convexMarket = new ConvexCrvLPMarket(
            owner,
            IMarketCore.MarketInit({
                tgUSD: tgUsd,
                controlTower: controlTower,
                irCalculator: irCalculator,
                collatToken: initP.marketInit.collat,
                collatOracle: oracles[collat],
                maxLTV: initP.marketInit.maxLTV,
                maxMarketDebt: initP.marketInit.maxMarketDebt,
                liquidationThreshold: initP.marketInit.liquidationThreshold,
                minimumLoan: initP.marketInit.minimumLoan
            }),
            rewardAccumulator,
            initP.rewards,
            initP.cvxRewardToken,
            initP.pid
        );
        assertEq(address(convexMarket.collatOracle()), address(oracles[collat]), "Collat oracle address setup");

        _toggleMarket_dealCollat_verifyParams(address(convexMarket), initP.marketInit.collat);

        labeliser.labeliseNewConvexCrvMarket(address(collat), collat.symbol(), address(convexMarket), address(initP.cvxRewardToken));

        return convexMarket;
    }

    function deployConvexFxnLPMarket(IERC20Metadata collat) public returns (ConvexFxnLPMarket) {
        ParamsInitConvexFxnLPMarket memory initP = cvxFxnLPMaps[address(collat)];

        assertTrue(address(initP.marketInit.collat) != address(0), "No init params for LP");
        assertTrue(address(oracles[collat]) != address(0), "Oracle not setup");

        /// Initialize reward tokens for the market
        ConvexFxnLPMarket convexMarket = new ConvexFxnLPMarket(
            owner,
            IMarketCore.MarketInit({
                tgUSD: tgUsd,
                controlTower: controlTower,
                irCalculator: irCalculator,
                collatToken: initP.marketInit.collat,
                collatOracle: oracles[collat],
                maxLTV: initP.marketInit.maxLTV,
                maxMarketDebt: initP.marketInit.maxMarketDebt,
                liquidationThreshold: initP.marketInit.liquidationThreshold,
                minimumLoan: initP.marketInit.minimumLoan
            }),
            rewardAccumulator,
            initP.rewards,
            initP.pid
        );
        _toggleMarket_dealCollat_verifyParams(address(convexMarket), initP.marketInit.collat);

        labeliser.labeliseNewConvexFxnMarket(address(collat), collat.symbol(), address(convexMarket), address(convexMarket.stakingProxyVault()));

        return convexMarket;
    }

    function giveCollateralToUsers(IERC20Metadata collat) public {
        deal(address(collat), usr1, 1_000_000_000 * 10 ** 18);
        deal(address(collat), usr2, 1_000_000_000 * 10 ** 18);
        deal(address(collat), usr3, 1_000_000_000 * 10 ** 18);
        deal(address(collat), usr4, 1_000_000_000 * 10 ** 18);
    }

    function _toggleMarket_dealCollat_verifyParams(address market, IERC20Metadata collat) internal {
        assertTrue(address(collat) != address(0), "No init params for LP");
        assertTrue(address(oracles[collat]) != address(0), "Oracle not setup");

        vm.startPrank(owner);
        controlTower.toggleMarkets(Array.memoryAddress([address(market)]));
        irCalculator.setUpMarketRewards(
            market,
            IRCalculator.IRParams({sigma: 2750000000000000, r0: 5 ether, irStartPrice: 995000000000000000}),
            IRCalculator.RCParams({startCutPercentage: 50_000, endCutPercentage: 100_000, stepAmount: 4, startCutPrice: 995000000000000000, endCutPrice: 900000000000000000})
        );
        vm.stopPrank();

        giveCollateralToUsers(collat);
    }

    // function setUpSingleRandomMarket() public {
    //     previewDeposits = new PreviewDeposits();
    //     vaultStruct = createAndGetRandomMarket();

    //     llamaVault = vaultStruct.llamaVault;
    //     pid = vaultStruct.pid;
    //     crvGauge = vaultStruct.crvGauge;
    //     crvController = vaultStruct.crvController;
    //     crvAmm = vaultStruct.crvAmm;
    //     cvxRewardToken = vaultStruct.cvxRewardToken;
    //     cvxVaultToken = vaultStruct.cvxVaultToken;
    //     lendAsset = vaultStruct.lendAsset;
    //     gUSD = vaultStruct.gUSD;
    //     scvUSD = vaultStruct.scvUSD;
    //     scvUSDAutoCompound = vaultStruct.scvUSDAutoCompound;

    //     string memory collateralSymbol = IERC20Metadata(llamaVault.collateral_token()).symbol();

    //     vm.label(address(llamaVault), string.concat("LLAMA_VAULT_", collateralSymbol));
    //     vm.label(address(crvGauge), string.concat("CRV_GAUGE_", collateralSymbol));
    //     vm.label(address(crvController), string.concat("CRV_CONTROLLER_", collateralSymbol));
    //     vm.label(address(crvAmm), string.concat("CRV_AMM_", collateralSymbol));
    //     vm.label(address(cvxRewardToken), string.concat("CVX_REWARD_TOKEN_", collateralSymbol));
    //     vm.label(address(cvxVaultToken), string.concat("CVX_VAULT_TOKEN_", collateralSymbol));
    //     vm.label(address(lendAsset), "CRVUSD");
    //     vm.label(address(gUSD), string.concat("GUSD_", collateralSymbol));
    //     vm.label(address(scvUSD), string.concat("SCVUSD_", collateralSymbol));
    //     vm.label(address(scvUSDAutoCompound), string.concat("SCVUSD_AUTOCOMP_", collateralSymbol));
    // }

    // function createAndGetRandomMarket() public returns (CvxStruct memory) {
    //     previewDeposits = new PreviewDeposits();
    //     // console.log("Ici c'est la , ", previewDeposits.aa(), address(previewDeposits));
    //     // Pick a random vault and its related data
    //     CvxStruct memory cvxStruct = getStruct(pickRandomVault());

    //     // Create param for createMarket
    //     uint256[] memory pids = new uint256[](1);
    //     pids[0] = cvxStruct.pid;

    //     vm.recordLogs();
    //     vm.prank(owner);

    //     splitter.createMarkets(pids);

    //     // Retrieve the logs from createCvxMarket
    //     Vm.Log[] memory entries = vm.getRecordedLogs();

    //     // The Event 'CreateCvxMarket' is the last of the transaction so we need to pick the last from the 'entries' list
    //     Vm.Log memory createLog = entries[entries.length - 1];

    //     (scvUSDCvx _scvUSD, SplitterTokenComp _scvUSDAutoCompound, gUSDCvx _gUSD) = abi.decode(createLog.data, (scvUSDCvx, SplitterTokenComp, gUSDCvx));
    //     cvxStruct.gUSD = _gUSD;
    //     cvxStruct.scvUSD = _scvUSD;
    //     cvxStruct.scvUSDAutoCompound = _scvUSDAutoCompound;
    //     return cvxStruct;
    // }

    // function pickRandomVault() public returns (ILlamaVault) {
    //     uint256 randomIndex = vm.randomUint();
    //     randomIndex = bound(randomIndex, 0, llamaVaultArray.length - 1);
    //     return llamaVaultArray[randomIndex];
    // }

    // function getStruct(ILlamaVault _llamaVault) public view returns (CvxStruct memory) {
    //     return structsMap[_llamaVault];
    // }

    // function getLlamaVaults() public view returns (ILlamaVault[] memory) {
    //     return llamaVaultArray;
    // }

    // function setSplitterTokens(ILlamaVault _llamaVault, gUSDCvx _gUSD, scvUSDCvx _scvUSD) public {
    //     structsMap[_llamaVault].gUSD = _gUSD;
    //     structsMap[_llamaVault].scvUSD = _scvUSD;
    // }

    // function getShareAmountAfterSociabilization(uint256 sharesAmount, bool isStake) public view returns (uint256, uint256) {
    //     uint256 feeTakenOrGiven;
    //     if (isStake) {
    //         feeTakenOrGiven = gUSD.socFeePending();
    //         sharesAmount += feeTakenOrGiven;
    //     } else {
    //         feeTakenOrGiven = (sharesAmount * gUSD.socFeePercentage()) / gUSD.DENOMINATOR();
    //         sharesAmount -= feeTakenOrGiven;
    //     }
    //     return (sharesAmount, feeTakenOrGiven);
    // }
}
