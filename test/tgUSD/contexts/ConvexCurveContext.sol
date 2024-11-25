// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./OraclesContext.sol";

import "../../../src/tgUSD/Market/Convex/ConvexCrvLPMarket.sol";
import "../../../src/tgUSD/Market/Convex/ConvexFxnLPMarket.sol";

import "../../../src/tgUSD/Market/MarketNoRewards.sol";

import "../handler/Features/HProcessRewards.sol";
import "../handler/Features/HBorrow.sol";
import "../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
import "../handler/Features/ConvexCrv/HWithdrawConvexCrvLP.sol";

import "../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";
import "../handler/Features/ConvexFxn/HWithdrawConvexFxnLP.sol";

import "../handler/Features/NoRewards/HDepositNoRewards.sol";
import "../handler/Features/NoRewards/HWithdrawNoRewards.sol";
import "../handler/Features/NoRewards/HWithdrawNoRewards.sol";
import "../../../src/interfaces/internals/tgUSD/IMarketCore.sol";

contract ConvexCurveContext is OraclesContext {
    IMarketCore[] cvxCurveLPMarket;
    mapping(address => ParamsInitConvexCurveLPMarket) public cvxCurveLPMaps;
    mapping(address => ParamsInitConvexFxnLPMarket) public cvxFxnLPMaps;

    mapping(address => MarketInitSimplified) public noRewardsMaps;

    struct ParamsInitConvexCurveLPMarket {
        MarketInitSimplified marketInit;
        IERC20Metadata[] rewards;
        ICvxRewardToken cvxRewardToken;
        uint256 pid;
    }

    struct ParamsInitConvexFxnLPMarket {
        MarketInitSimplified marketInit;
        IERC20Metadata[] rewards;
        uint256 pid;
    }

    struct MarketInitSimplified {
        IERC20Metadata collat;
        uint256 maxLTV;
        uint256 maxMarketDebt;
        uint256 liquidationThreshold;
        uint256 minimumLoan;
    }

    constructor() {
        // Convex Curve - CRVUSD_USDC
        IERC20Metadata[] memory _rewardsCrvCvx = Array.memoryIERC20([AddrClassicERC20.TOKEN_CRV, AddrClassicERC20.TOKEN_CVX]);

        cvxCurveLPMaps[address(AddrCurveStableLP.CRVUSD_USDC)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                collat: AddrCurveStableLP.CRVUSD_USDC,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            rewards: _rewardsCrvCvx,
            cvxRewardToken: AddrCvxRewardTokens.CRVUSD_USDC_LP,
            pid: PidCvxCrvBooster.CRVUSD_USDC_LP
        });

        // Convex FXN - USDC_FXUSD

        IERC20Metadata[] memory _rewardsFxn = Array.memoryIERC20([AddrClassicERC20.TOKEN_FXN]);

        cvxFxnLPMaps[address(AddrCurveStableLP.USDC_FXUSD)] = ParamsInitConvexFxnLPMarket({
            marketInit: MarketInitSimplified({
                collat: AddrCurveStableLP.USDC_FXUSD,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            rewards: _rewardsFxn,
            pid: PidCvxFxnBooster.USDC_FXUSD_LP
        });

        // sDAI

        noRewardsMaps[address(AddrClassicERC20.TOKEN_SDAI)] = MarketInitSimplified({
            collat: AddrClassicERC20.TOKEN_SDAI,
            maxLTV: 85_000,
            liquidationThreshold: 93_000,
            minimumLoan: 3_000 ether,
            maxMarketDebt: 1_000_000 ether
        });
    }

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
                tgUSDOracle: oracles[tgUsd],
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

        vm.startPrank(owner);
        controlTower.toggleMarkets(Array.memoryAddress([address(convexMarket)]));
        vm.stopPrank();
        giveCollateralToUsers(collat);

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
                tgUSDOracle: oracles[tgUsd],
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
        vm.startPrank(owner);
        controlTower.toggleMarkets(Array.memoryAddress([address(convexMarket)]));
        vm.stopPrank();

        giveCollateralToUsers(collat);

        labeliser.labeliseNewConvexFxnMarket(address(collat), collat.symbol(), address(convexMarket), address(convexMarket.stakingProxyVault()));

        return convexMarket;
    }

    function deployNoRewardsMarket(IERC20Metadata collat) public returns (MarketNoRewards) {
        MarketInitSimplified memory initP = noRewardsMaps[address(collat)];

        assertTrue(address(initP.collat) != address(0), "No init params for LP");
        assertTrue(address(oracles[collat]) != address(0), "Oracle not setup");

        /// Initialize reward tokens for the market
        MarketNoRewards marketNoRewards = new MarketNoRewards(
            owner,
            IMarketCore.MarketInit({
                tgUSD: tgUsd,
                controlTower: controlTower,
                tgUSDOracle: oracles[tgUsd],
                collatToken: initP.collat,
                collatOracle: oracles[collat],
                maxLTV: initP.maxLTV,
                maxMarketDebt: initP.maxMarketDebt,
                liquidationThreshold: initP.liquidationThreshold,
                minimumLoan: initP.minimumLoan
            })
        );

        vm.startPrank(owner);
        controlTower.toggleMarkets(Array.memoryAddress([address(marketNoRewards)]));
        vm.stopPrank();

        giveCollateralToUsers(collat);

        labeliser.labeliseNewNoRewardsMarket(address(collat), collat.symbol(), address(marketNoRewards));

        return marketNoRewards;
    }

    function giveCollateralToUsers(IERC20Metadata collat) public {
        deal(address(collat), usr1, 1_000_000_000 * 10 ** 18);
        deal(address(collat), usr2, 1_000_000_000 * 10 ** 18);
        deal(address(collat), usr3, 1_000_000_000 * 10 ** 18);
        deal(address(collat), usr4, 1_000_000_000 * 10 ** 18);
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
