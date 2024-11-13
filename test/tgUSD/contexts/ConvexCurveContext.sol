// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TgUSDDeployContext.sol";

import "../../../src/tgUSD/Market/Convex/ConvexCrvLPMarket.sol";
contract ConvexCurveContext is TgUSDDeployContext {
    IMarket[] cvxCurveLPMarket;
    mapping(address => ParamsInitConvexCurveLPMarket) public cvxCurveLPMaps;

    struct ParamsInitConvexCurveLPMarket {
        ICurveStableSwapNG collat;
        CurveStableLPOracleParams oracleParams;
        MarketInitSimplified marketInit;
        IERC20[] rewards;
        ICvxRewardToken cvxRewardToken;
        uint256 pid;
    }

    struct CurveStableLPOracleParams {
        IAggregatorV3 coin0Oracle;
        IAggregatorV3 coin1Oracle;
    }
    struct MarketInitSimplified {
        uint256 maxLTV;
        uint256 maxMarketDebt;
        uint256 liquidationThreshold;
        uint256 minimumLoan;
    }

    constructor() {
        // AddrCurveStableLP.CRVUSD_USDC
        IERC20[] memory _rewardsCrvCvx = new IERC20[](2);
        _rewardsCrvCvx[0] = AddrClassicERC20.TOKEN_CRV;
        _rewardsCrvCvx[1] = AddrClassicERC20.TOKEN_CVX;

        cvxCurveLPMaps[address(AddrCurveStableLP.CRVUSD_USDC)] = ParamsInitConvexCurveLPMarket({
            collat: AddrCurveStableLP.CRVUSD_USDC,
            oracleParams: CurveStableLPOracleParams({coin0Oracle: AddrChainlinkOracle.CRVUSD, coin1Oracle: AddrChainlinkOracle.USDC}),
            marketInit: MarketInitSimplified({maxLTV: 85_000, liquidationThreshold: 93_000, minimumLoan: 3_000 ether, maxMarketDebt: 1_000_000 ether}),
            rewards: _rewardsCrvCvx,
            cvxRewardToken: AddrCvxRewardTokens.CRVUSD_USDC_LP,
            pid: PidCvxBooster.CRVUSD_USDC_LP
        });
    }

    function deployConvexCurveLPMarket(IERC20Metadata collat) public returns (ConvexCrvLPMarket) {
        ParamsInitConvexCurveLPMarket memory initP = cvxCurveLPMaps[address(collat)];

        require(address(initP.collat) != address(0), "NO_INIT_PARAMS_FOR_LP");

        /// Initialize reward tokens for the market
        ConvexCrvLPMarket convexMarket = new ConvexCrvLPMarket(
            IMarket.MarketInit({
                tgUSD: tgUsd,
                tgUSDOracle: tgUsdOracle,
                collatToken: initP.collat,
                collatOracle: new CurveStableLPOracle(initP.collat, initP.oracleParams.coin0Oracle, initP.oracleParams.coin1Oracle),
                irMinter: address(irMinter),
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

        toggleIrProducerAndRewardAccumulator(address(convexMarket));
        giveCollateralToUsers(collat);

        return convexMarket;
    }

    function toggleIrProducerAndRewardAccumulator(address _convexMarket) public {
        address[] memory markets = new address[](1);
        markets[0] = _convexMarket;

        irMinter.toggleIRProducers(markets);

        rewardAccumulator.toggleMarketRewards(markets);
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
