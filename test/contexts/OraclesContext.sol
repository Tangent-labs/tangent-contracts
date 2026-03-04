// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./USGDeployContext.sol";

import {OracleCoinFromCurveLP} from "../../src/USG/Oracles/Token/OracleCoinFromCurveLP.sol";
import {OracleERC4626} from "../../src/USG/Oracles/Token/OracleERC4626.sol";

import {OracleChainlinkWrapper} from "../../src/USG/Oracles/Token/OracleChainlinkWrapper.sol";
import {OracleRedstoneWrapperFallback} from "../../src/USG/Oracles/Token/OracleRedstoneWrapperFallback.sol";

import {OracleDuoPoolStable} from "../../src/USG/Oracles/CurveLP/OracleDuoPoolStable.sol";
// import {OracleTriPoolStable} from "../../src/USG/Oracles/CurveLP/OracleTriPoolStable.sol";
import {OracleCryptoSwap} from "../../src/USG/Oracles/CurveLP/OracleCryptoSwap.sol";

import {OraclePendlePT} from "../../src/USG/Oracles/Pendle/OraclePendlePT.sol";
import {OraclePendlePTLinearDiscount} from "../../src/USG/Oracles/Pendle/OraclePendlePTLinearDiscount.sol";
// import {OraclePendleLP} from "../../src/USG/Oracles/Pendle/OraclePendleLP.sol";

import {IRCalculator} from "../../src/USG/Utilities/IRCalculator.sol";
import {IAggregatorStablePriceV3} from "../../src/interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";
import {IPegKeeperRegulator} from "../../src/interfaces/externals/LlamaLend/IPegKeeperRegulator.sol";
import {IPegKeeperV2} from "../../src/interfaces/externals/LlamaLend/IPegKeeperV2.sol";

contract OraclesContext is USGDeployContext {
    IRCalculator public irCalculator;
    mapping(IERC20 => IPriceOracle) public oracles;

    IAggregatorStablePriceV3 public USGOracle;

    IPegKeeperRegulator public pegKeeperRegulator;

    IPegKeeperV2 public pegKeeperUSG_USDC;
    IPegKeeperV2 public pegKeeperUSG_wcrvUSD;

    constructor() {
        vm.startPrank(owner);
        // Oracle USG

        USGOracle = IAggregatorStablePriceV3(deployCode("AggregatorStablePriceV3", abi.encode(usg, uint256(1000000000000000), owner)));
        vm.label(address(USGOracle), "Oracle USG");

        irCalculator = new IRCalculator(owner, controlTower, USGOracle, usg);

        usg.setIsIRProducer(address(irCalculator), true);

        rewardAccumulator = new RewardAccumulator(owner, controlTower, USGOracle);

        vm.label(address(rewardAccumulator), "RewardAccumulator");

        marketCreator = new MarketCreator(
            owner,
            controlTower,
            usg,
            irCalculator,
            rewardAccumulator,
            zappingProxy,
            convexCrvLPMarketImplem,
            convexFxnLPMarketImplem,
            curveGaugeMarketImplem,
            stakeDaoVaultV2MarketImplem,
            marketBasicERC20Implem
        );
        controlTower.setIsMarketCreator(address(marketCreator), true);

        vm.label(address(marketCreator), "MarketCreator");

        vm.stopPrank();
        setupChainlinkOracles();
        setupSimpleTokenOraclesWithCurveLP();
        setupSavingAccountOracles();
        setupCurveStableLPOracles();
        setupCurveTriCryptoSwapLPOracles();
        setupPendlePTTokens();
        // setupPendleLPTokens();
    }

    function setupUSGOracle() public {
        vm.startPrank(owner);
        USGOracle.add_price_pair(address(lpDeploymentContext.USGLPs("USG-USDC")));
        USGOracle.add_price_pair(address(lpDeploymentContext.USGLPs("USG-wcrvUSD")));

        pegKeeperRegulator = IPegKeeperRegulator(deployCode("PegKeeperRegulator", abi.encode(usg, USGOracle, feeTreasury, owner, owner)));
        pegKeeperUSG_USDC = IPegKeeperV2(deployCode("PegKeeperV2", abi.encode(lpDeploymentContext.USGLPs("USG-USDC"), 20000, pegKeeperRegulator, owner)));
        pegKeeperUSG_wcrvUSD = IPegKeeperV2(deployCode("PegKeeperV2", abi.encode(lpDeploymentContext.USGLPs("USG-wcrvUSD"), 20000, pegKeeperRegulator, owner)));

        usg.setIsPegKeeper(address(pegKeeperUSG_USDC), true);
        usg.setIsPegKeeper(address(pegKeeperUSG_wcrvUSD), true);

        address[] memory pairs = new address[](2);
        pairs[0] = address(pegKeeperUSG_USDC);
        pairs[1] = address(pegKeeperUSG_wcrvUSD);

        pegKeeperRegulator.add_peg_keepers(pairs);
        vm.stopPrank();
    }

    function setupChainlinkOracles() internal {
        oracles[AddrClassicERC20.DAI] = new OracleChainlinkWrapper(AddrChainlinkOracle.DAI, 1000000000000, address(0), "DAI / USD");
        vm.label(address(AddrChainlinkOracle.DAI), "Oracle DAI");

        oracles[AddrClassicERC20.USDS] = new OracleChainlinkWrapper(AddrChainlinkOracle.USDS, 1000000000000, address(0), "USDS / USD");
        vm.label(address(AddrChainlinkOracle.USDS), "Oracle USDS");

        OracleChainlinkWrapper USDeFallback = new OracleChainlinkWrapper(AddrRestoneOracle.USDe, 1000000000000, address(0), "Redstonne Fallback USDe / USD");
        oracles[AddrClassicERC20.USDe] = new OracleChainlinkWrapper(AddrChainlinkOracle.USDe, 1000000000000, address(USDeFallback), "USDe / USD");
        vm.label(address(AddrChainlinkOracle.USDe), "Oracle USDe");

        OracleChainlinkWrapper USDCFallback = new OracleChainlinkWrapper(AddrRestoneOracle.USDC, 1000000000000, address(0), "Redstonne Fallback USDC / USD");
        oracles[AddrClassicERC20.USDC] = new OracleChainlinkWrapper(AddrChainlinkOracle.USDC, 1000000000000, address(USDCFallback), "USDC / USD");
        vm.label(address(AddrChainlinkOracle.USDC), "Oracle USDC");

        OracleChainlinkWrapper USDTFallback = new OracleChainlinkWrapper(AddrRestoneOracle.USDT, 1000000000000, address(0), "Redstonne Fallback USDT / USD");
        oracles[AddrClassicERC20.USDT] = new OracleChainlinkWrapper(AddrChainlinkOracle.USDT, 1000000000000, address(USDTFallback), "USDT / USD");
        vm.label(address(AddrChainlinkOracle.USDT), "Oracle USDT");

        oracles[AddrClassicERC20.crvUSD] = new OracleChainlinkWrapper(AddrChainlinkOracle.crvUSD, 1000000000000, address(0), "crvUSD / USD");
        vm.label(address(AddrChainlinkOracle.crvUSD), "Oracle crvUSD");

        oracles[AddrClassicERC20.GHO] = new OracleChainlinkWrapper(AddrChainlinkOracle.GHO, 1000000000000, address(0), "GHO / USD");
        vm.label(address(AddrChainlinkOracle.GHO), "Oracle GHO");

        OracleChainlinkWrapper ETHFallback = new OracleChainlinkWrapper(AddrRestoneOracle.ETH, 1000000000000, address(0), "Redstone Fallback ETH / USD");
        oracles[AddrClassicERC20.WETH] = new OracleChainlinkWrapper(AddrChainlinkOracle.ETH, 1000000000000, address(ETHFallback), "ETH / USD");
        vm.label(address(AddrChainlinkOracle.ETH), "Oracle ETH");

        oracles[AddrClassicERC20.WBTC] = new OracleChainlinkWrapper(AddrChainlinkOracle.BTC, 1000000000000, address(0), "WBTC / BTC");
        vm.label(address(AddrChainlinkOracle.BTC), "Oracle BTC");

        oracles[AddrClassicERC20.cbBTC] = new OracleChainlinkWrapper(AddrChainlinkOracle.cbBTC, 1000000000000, address(0), "cbBTC / USD");
        vm.label(address(AddrChainlinkOracle.cbBTC), "Oracle cbBTC");

        oracles[AddrClassicERC20.CRV] = new OracleChainlinkWrapper(AddrChainlinkOracle.CRV, 1000000000000, address(0), "CRV / USD");
        vm.label(address(AddrChainlinkOracle.CRV), "Oracle CRV");

        OracleChainlinkWrapper USRFallback = new OracleChainlinkWrapper(AddrRestoneOracle.USR, 1000000000000, address(0), "Redstone Fallback USR / USD");
        oracles[AddrClassicERC20.USR] = new OracleChainlinkWrapper(AddrChainlinkOracle.USR, 1000000000000, address(USRFallback), "USR / USD");
        vm.label(address(AddrChainlinkOracle.USR), "Oracle USR");

        oracles[AddrClassicERC20.stETH] = new OracleChainlinkWrapper(AddrChainlinkOracle.stETH, 1000000000000, address(0), "stETH / USD");
        vm.label(address(AddrChainlinkOracle.stETH), "Oracle stETH");

        oracles[AddrClassicERC20.cbBTC] = new OracleChainlinkWrapper(AddrChainlinkOracle.cbBTC, 1000000000000, address(0), "cbBTC / USD");
        vm.label(address(AddrChainlinkOracle.cbBTC), "Oracle cbBTC");

        oracles[AddrClassicERC20.CRV] = new OracleChainlinkWrapper(AddrChainlinkOracle.CRV, 1000000000000, address(0), "CRV / USD");
        vm.label(address(AddrChainlinkOracle.CRV), "Oracle CRV");

        oracles[AddrClassicERC20.RLUSD] = new OracleChainlinkWrapper(AddrChainlinkOracle.RLUSD, 1000000000000, address(0), "RLUSD / USD");
        vm.label(address(AddrChainlinkOracle.RLUSD), "Oracle RLUSD");

        oracles[AddrClassicERC20.PYUSD] = new OracleChainlinkWrapper(AddrChainlinkOracle.PYUSD, 1000000000000, address(0), "PYUSD / USD");
        vm.label(address(AddrChainlinkOracle.PYUSD), "Oracle PYUSD");
    }

    function setupSimpleTokenOraclesWithCurveLP() internal {
        // Oracle fxUSD
        oracles[AddrClassicERC20.fxUSD] = new OracleCoinFromCurveLP(address(AddrCurveStableLP.USDC_fxUSD), oracles[AddrClassicERC20.USDC], 0, "fxUSD / USD");
        vm.label(address(oracles[AddrClassicERC20.fxUSD]), "Oracle fxUSD");

        // Oracle DOLA
        oracles[AddrClassicERC20.DOLA] = new OracleCoinFromCurveLP(address(AddrCurveStableLP.DOLA_sUSDS), oracles[AddrClassicERC20.USDS], 1, "DOLA / USD");
        vm.label(address(oracles[AddrClassicERC20.DOLA]), "Oracle DOLA");

        // Oracle frxUSD
        oracles[AddrClassicERC20.frxUSD] = new OracleCoinFromCurveLP(address(AddrCurveStableLP.frxUSD_sUSDS), oracles[AddrClassicERC20.USDS], 0, "frxUSD / USD");
        vm.label(address(oracles[AddrClassicERC20.frxUSD]), "Oracle frxUSD");

        // Oracle frxETH
        oracles[AddrClassicERC20.frxETH] = new OracleCoinFromCurveLP(address(AddrCurveStableLP.WETH_frxETH), oracles[AddrClassicERC20.WETH], 0, "frxETH / USD");
        vm.label(address(oracles[AddrClassicERC20.frxETH]), "Oracle frxETH");

        // Oracle pxETH
        oracles[AddrClassicERC20.pxETH] = new OracleCoinFromCurveLP(address(AddrCurveStableLP.WETH_pxETH), oracles[AddrClassicERC20.WETH], 0, "pxETH / USD");
        vm.label(address(oracles[AddrClassicERC20.pxETH]), "Oracle pxETH");

        // Oracle eBTC
        oracles[AddrClassicERC20.eBTC] = new OracleCoinFromCurveLP(address(AddrCurveStableLP.eBTC_WBTC), oracles[AddrClassicERC20.WBTC], 1, "eBTC / USD");
        vm.label(address(oracles[AddrClassicERC20.eBTC]), "Oracle eBTC");

        // Oracle RLP
        oracles[AddrClassicERC20.RLP] = new OracleCoinFromCurveLP(address(AddrCryptoSwapLP.USR_RLP), oracles[AddrClassicERC20.USR], 0, "RLP / USD");
        vm.label(address(oracles[AddrClassicERC20.RLP]), "Oracle RLP");

        // Oracle CVX
        oracles[AddrClassicERC20.CVX] = new OracleCoinFromCurveLP(address(AddrCryptoSwapLP.CVX_ETH_POOL), oracles[AddrClassicERC20.WETH], 0, "CVX / USD");
        vm.label(address(oracles[AddrClassicERC20.CVX]), "Oracle CVX");
    }

    function setupCurveTriCryptoSwapLPOracles() internal {
        // Oracle USDT_WBTC_ETH
        oracles[AddrCryptoSwapLP.USDT_WBTC_ETH] = new OracleCryptoSwap(address(AddrCryptoSwapLP.USDT_WBTC_ETH), oracles[AddrClassicERC20.USDT], "USDT_WBTC_ETH / USD");
        vm.label(address(oracles[AddrCryptoSwapLP.USDT_WBTC_ETH]), "Oracle LP USDT/WBTC/ETH");

        // Oracle USDC_WBTC_ETH
        oracles[AddrCryptoSwapLP.USDC_WBTC_ETH] = new OracleCryptoSwap(address(AddrCryptoSwapLP.USDC_WBTC_ETH), oracles[AddrClassicERC20.USDC], "USDC_WBTC_ETH / USD");
        vm.label(address(oracles[AddrCryptoSwapLP.USDC_WBTC_ETH]), "Oracle LP USDC/WBTC/ETH");

        // Oracle CRVUSD_ETH_CRV
        oracles[AddrCryptoSwapLP.crvUSD_ETH_CRV] = new OracleCryptoSwap(address(AddrCryptoSwapLP.crvUSD_ETH_CRV), oracles[AddrClassicERC20.crvUSD], "crvUSD_ETH_CRV / USD");
        vm.label(address(oracles[AddrCryptoSwapLP.crvUSD_ETH_CRV]), "Oracle LP crvUSD/ETH/CRV");

        // Oracle GHO_CBBTC_ETH
        oracles[AddrCryptoSwapLP.GHO_cbBTC_ETH] = new OracleCryptoSwap(address(AddrCryptoSwapLP.GHO_cbBTC_ETH), oracles[AddrClassicERC20.GHO], "GHO_cbBTC_ETH / USD");
        vm.label(address(oracles[AddrCryptoSwapLP.GHO_cbBTC_ETH]), "Oracle LP GHO/cbBTC/ETH");

        // Oracle USR_RLP
        oracles[AddrCryptoSwapLP.USR_RLP] = new OracleCryptoSwap(address(AddrCryptoSwapLP.USR_RLP), oracles[AddrClassicERC20.USR], "USR_RLP / USD");
        vm.label(address(oracles[AddrCryptoSwapLP.USR_RLP]), "Oracle LP USR/RLP");

        // Oracle CVX_ETH
        oracles[AddrCryptoSwapLP.CVX_ETH_LP] = new OracleCryptoSwap(address(AddrCryptoSwapLP.CVX_ETH_POOL), oracles[AddrClassicERC20.WETH], "CVX_ETH / USD");
        vm.label(address(oracles[AddrCryptoSwapLP.CVX_ETH_LP]), "Oracle LP CVX/ETH");
    }

    function setupCurveStableLPOracles() internal {
        // Oracle CRVUSD_USDC
        oracles[AddrCurveStableLP.USDC_crvUSD] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.USDC_crvUSD),
            oracles[AddrClassicERC20.USDC],
            oracles[AddrClassicERC20.crvUSD],
            "crvUSD_USDC / USD"
        );
        vm.label(address(oracles[AddrCurveStableLP.USDC_crvUSD]), "Oracle LP crvUSD/USDC");

        // Oracle CRVUSD_USDT
        oracles[AddrCurveStableLP.USDT_crvUSD] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.USDT_crvUSD),
            oracles[AddrClassicERC20.USDT],
            oracles[AddrClassicERC20.crvUSD],
            "crvUSD_USDT / USD"
        );
        vm.label(address(oracles[AddrCurveStableLP.USDT_crvUSD]), "Oracle LP crvUSD/USDT");

        // Oracle USDC_FXUSD
        oracles[AddrCurveStableLP.USDC_fxUSD] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.USDC_fxUSD),
            oracles[AddrClassicERC20.USDC],
            oracles[AddrClassicERC20.fxUSD],
            "USDC_fxUSD / USD"
        );
        vm.label(address(oracles[AddrCurveStableLP.USDC_fxUSD]), "Oracle LP USDC/fxUSD");

        // // Oracle TriStable DAI/USDC/USDT
        // oracles[AddrCurveStableLP.TRI_USD_LP] = new OracleTriPoolStable(
        //     address(AddrCurveStableLP.TRI_USD_POOL),
        //     oracles[AddrClassicERC20.DAI],
        //     oracles[AddrClassicERC20.USDC],
        //     oracles[AddrClassicERC20.USDT]
        // );
        // vm.label(address(oracles[AddrCurveStableLP.TRI_USD_LP]), "Oracle LP TriUSD");

        // Oracle frxETH/WETH
        oracles[AddrCurveStableLP.WETH_frxETH] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.WETH_frxETH),
            oracles[AddrClassicERC20.WETH],
            oracles[AddrClassicERC20.frxETH],
            "WETH_frxETH / USD"
        );
        vm.label(address(oracles[AddrCurveStableLP.WETH_frxETH]), "Oracle LP frxETH/ETH");

        // Oracle pxETH/WETH
        oracles[AddrCurveStableLP.WETH_pxETH] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.WETH_pxETH),
            oracles[AddrClassicERC20.WETH],
            oracles[AddrClassicERC20.pxETH],
            "WETH_pxETH / USD"
        );
        vm.label(address(oracles[AddrCurveStableLP.WETH_pxETH]), "Oracle LP pxETH/ETH");

        // Oracle ETH/stETH
        oracles[AddrCurveStableLP.ETH_stETH_LP] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.ETH_stETH_POOL),
            oracles[AddrClassicERC20.WETH],
            oracles[AddrClassicERC20.stETH],
            "ETH_stETH / USD"
        );
        vm.label(address(oracles[AddrCurveStableLP.WETH_pxETH]), "Oracle LP ETH/stETH");

        // Oracle sDAI/sUSDe
        oracles[AddrCurveStableLP.sDAI_sUSDe] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.sDAI_sUSDe),
            oracles[AddrClassicERC20.DAI],
            oracles[AddrClassicERC20.USDe],
            "sDAI_sUSDe / USD"
        );
        vm.label(address(oracles[AddrCurveStableLP.sDAI_sUSDe]), "Oracle LP sDAI/sUSDe");

        // Oracle scrvUSD/sDOLA
        oracles[AddrCurveStableLP.scrvUSD_sDOLA] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.scrvUSD_sDOLA),
            oracles[AddrClassicERC20.crvUSD],
            oracles[AddrClassicERC20.DOLA],
            "scrvUSD_sDOLA / USD"
        );
        vm.label(address(oracles[AddrCurveStableLP.scrvUSD_sDOLA]), "Oracle LP scrvUSD/sDOLA");

        // Oracle sUSDS/USDT
        oracles[AddrCurveStableLP.sUSDS_USDT] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.sUSDS_USDT),
            oracles[AddrClassicERC20.USDS],
            oracles[AddrClassicERC20.USDT],
            "sUSDS_USDT / USD"
        );
        vm.label(address(oracles[AddrCurveStableLP.sUSDS_USDT]), "Oracle LP sUSDS/USDT");

        // Oracle cbBTC/WBTC
        oracles[AddrCurveStableLP.cbBTC_WBTC] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.cbBTC_WBTC),
            oracles[AddrClassicERC20.cbBTC],
            oracles[AddrClassicERC20.WBTC],
            "cbBTC_WBTC / USD"
        );
        vm.label(address(oracles[AddrCurveStableLP.cbBTC_WBTC]), "Oracle LP cbBTC/WBTC");

        // Oracle frxUSD/sUSDS
        oracles[AddrCurveStableLP.frxUSD_sUSDS] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.frxUSD_sUSDS),
            oracles[AddrClassicERC20.frxUSD],
            oracles[AddrClassicERC20.USDS],
            "frxUSD_sUSDS / USD"
        );
        vm.label(address(oracles[AddrCurveStableLP.frxUSD_sUSDS]), "Oracle LP frxUSD/sUSDS");

        // Oracle RLUSD/USDC
        oracles[AddrCurveStableLP.RLUSD_USDC] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.RLUSD_USDC),
            oracles[AddrClassicERC20.USDC],
            oracles[AddrClassicERC20.RLUSD],
            "RLUSD_USDC / USD"
        );
        oracles[AddrCurveGauge.RLUSD_USDC] = oracles[AddrCurveStableLP.RLUSD_USDC];
        vm.label(address(oracles[AddrCurveStableLP.RLUSD_USDC]), "Oracle LP RLUSD/USDC");

        // Oracle PYUSD/USDC
        oracles[AddrCurveStableLP.PYUSD_USDC] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.PYUSD_USDC),
            oracles[AddrClassicERC20.PYUSD],
            oracles[AddrClassicERC20.USDC],
            "PYUSD_USDC / USD"
        );
        oracles[AddrCurveGauge.PYUSD_USDC] = oracles[AddrCurveStableLP.PYUSD_USDC];
        vm.label(address(oracles[AddrCurveStableLP.PYUSD_USDC]), "Oracle LP PYUSD/USDC");
    }

    function setupSavingAccountOracles() internal {
        // Oracle sDAI
        oracles[AddrERC4626.sDAI] = new OracleERC4626(AddrERC4626.sDAI, oracles[AddrClassicERC20.DAI], "sDAI / USD");
        vm.label(address(oracles[AddrERC4626.sDAI]), "Oracle sDAI");
        // Oracle sUSDS
        oracles[AddrERC4626.sUSDS] = new OracleERC4626(AddrERC4626.sUSDS, oracles[AddrClassicERC20.USDS], "sUSDS / USD");
        vm.label(address(oracles[AddrERC4626.sUSDS]), "Oracle sUSDS");
        // Oracle sUSDe
        oracles[AddrERC4626.sUSDe] = new OracleERC4626(AddrERC4626.sUSDe, oracles[AddrClassicERC20.USDe], "sUSDe / USD");
        vm.label(address(oracles[AddrERC4626.sUSDe]), "Oracle sUSDe");
        // Oracle sDOLA
        oracles[AddrERC4626.sDOLA] = new OracleERC4626(AddrERC4626.sDOLA, oracles[AddrClassicERC20.DOLA], "sDOLA / USD");
        vm.label(address(oracles[AddrERC4626.sDOLA]), "Oracle sDOLA");
        // Oracle scrvUSD
        oracles[AddrERC4626.scrvUSD] = new OracleERC4626(AddrERC4626.scrvUSD, oracles[AddrClassicERC20.crvUSD], "crvUSD / USD");
        vm.label(address(oracles[AddrERC4626.scrvUSD]), "Oracle scrvUSD");
        // Oracle wstUSR
        oracles[AddrERC4626.wstUSR] = new OracleERC4626(AddrERC4626.wstUSR, oracles[AddrClassicERC20.USR], "wstUSR / USD");
        vm.label(address(oracles[AddrERC4626.wstUSR]), "Oracle wstUSR");
        // Oracle sfrxUSD
        oracles[AddrERC4626.sfrxUSD] = new OracleERC4626(AddrERC4626.sfrxUSD, oracles[AddrClassicERC20.frxUSD], "sfrxUSD / USD");
        vm.label(address(oracles[AddrERC4626.sfrxUSD]), "Oracle sfrxUSD");
    }

    function setupPendlePTTokens() internal {
        // Oracle PT USDe_07_05_26
        oracles[AddrPTPendle.USDe_07_05_26] = new OraclePendlePT(AddrMarketPendle.USDe_07_05_26, oracles[AddrClassicERC20.USDe], 20, 18, "USDe_07_05_26 / USD");
        vm.label(address(oracles[AddrPTPendle.USDe_07_05_26]), "Oracle PT USDe_07_05_26");

        // Oracle PT sUSDe_07_05_26
        oracles[AddrPTPendle.sUSDe_07_05_26] = new OraclePendlePT(AddrMarketPendle.sUSDe_07_05_26, oracles[AddrERC4626.sUSDe], 20, 18, "sUSDe_07_05_26 / USD");
        vm.label(address(oracles[AddrPTPendle.sUSDe_07_05_26]), "Oracle PT sUSDe_07_05_26");

        // Oracle PT sUSDe_25_09_25
        oracles[AddrPTPendle.sUSDe_05_02_26] = new OraclePendlePT(AddrMarketPendle.sUSDe_05_02_26, oracles[AddrERC4626.sUSDe], 900, 18, "sUSDe_05_02_26 Linear / USD");
        vm.label(address(oracles[AddrPTPendle.sUSDe_05_02_26]), "Oracle PT sUSDe_05_02_26");

        // Oracle PT sUSDE 31_07_25
        oracles[AddrPTPendle.sUSDe_31_07_25] = new OraclePendlePT(AddrMarketPendle.sUSDe_31_07_25, oracles[AddrERC4626.sUSDe], 900, 18, "PT sUSDe 31/07/25 Linear / USD");
        vm.label(address(oracles[AddrPTPendle.sUSDe_31_07_25]), "Oracle PT sUSDe 31_07_25");

        // Oracle PT eUSDE 29_05_25
        oracles[AddrPTPendle.eUSDe_29_05_25] = new OraclePendlePT(AddrMarketPendle.eUSDe_29_05_25, oracles[AddrClassicERC20.USDe], 900, 18, "PT eUSDe 29/05/25 Linear / USD");
        vm.label(address(oracles[AddrPTPendle.eUSDe_29_05_25]), "Oracle PT eUSDe 29_05_25");

        // Oracle PT eBTC 26_06_25
        oracles[AddrPTPendle.eBTC_26_06_25] = new OraclePendlePT(AddrMarketPendle.eBTC_26_06_25, oracles[AddrClassicERC20.eBTC], 900, 18, "PT sUSDe 26/06/25 Linear / USD");
        vm.label(address(oracles[AddrPTPendle.eBTC_26_06_25]), "Oracle PT eBTC 26_06_25");

        // Oracle PT wstUSR_25_09_25
        oracles[AddrPTPendle.wstUSR_25_09_25] = new OraclePendlePT(AddrMarketPendle.wstUSR_25_09_25, oracles[AddrERC4626.wstUSR], 900, 18, "PT sUSDe 25/09/25 Linear / USD");
        vm.label(address(oracles[AddrPTPendle.wstUSR_25_09_25]), "Oracle PT wstUSR_25_09_25");

        // Oracle PT sUSDe_25_09_25
        oracles[AddrPTPendle.sUSDe_25_09_25] = new OraclePendlePT(AddrMarketPendle.sUSDe_25_09_25, oracles[AddrERC4626.sUSDe], 900, 18, "PT sUSDe 25/09/25 Linear / USD");
        vm.label(address(oracles[AddrPTPendle.sUSDe_25_09_25]), "Oracle PT sUSDe_25_09_25");

        // Oracle PT USDe_25_09_25
        oracles[AddrPTPendle.USDe_25_09_25] = new OraclePendlePT(AddrMarketPendle.USDe_25_09_25, oracles[AddrClassicERC20.USDe], 900, 18, "PT sUSDe 25/09/25 Linear / USD");
        vm.label(address(oracles[AddrPTPendle.USDe_25_09_25]), "Oracle PT USDe_25_09_25");

        // Oracle PT USR_04_09_25
        oracles[AddrPTPendle.USR_04_09_25] = new OraclePendlePT(AddrMarketPendle.USR_04_09_25, oracles[AddrClassicERC20.USR], 900, 18, "PT sUSDe 04/09/25 Linear");
        vm.label(address(oracles[AddrPTPendle.USR_04_09_25]), "Oracle PT USR_04_09_25");

        // Oracle PT USDe_27_11_25
        oracles[AddrPTPendle.USDe_27_11_25] = new OraclePendlePT(AddrMarketPendle.USDe_27_11_25, oracles[AddrClassicERC20.USDe], 900, 18, "PT sUSDe 27/11/25 Linear");
        vm.label(address(oracles[AddrPTPendle.USDe_27_11_25]), "Oracle PT USDe_27_11_25");

        // Oracle PT sUSDe_27_11_25
        oracles[AddrPTPendle.sUSDe_27_11_25] = new OraclePendlePT(AddrMarketPendle.sUSDe_27_11_25, oracles[AddrERC4626.sUSDe], 900, 18, "PT sUSDe 27/11/25 Linear");
        vm.label(address(oracles[AddrPTPendle.sUSDe_27_11_25]), "Oracle PT sUSDe_27_11_25");

        // Oracle PT wstUSR_25_09_25
        oracles[AddrPTPendle.wstUSR_29_01_26] = new OraclePendlePT(AddrMarketPendle.wstUSR_29_01_26, oracles[AddrERC4626.wstUSR], 900, 18, "PT sUSDe 25/09/25 Linear / USD");
        vm.label(address(oracles[AddrPTPendle.wstUSR_29_01_26]), "Oracle PT wstUSR_25_09_25");
    }

    // function setupPendleLPTokens() internal {
    //     // Oracle LP sUSDE 31_07_25
    //     oracles[AddrMarketPendle.sUSDe_31_07_25] = new OraclePendleLP(AddrMarketPendle.sUSDe_31_07_25, oracles[AddrClassicERC20.USDe]);
    //     vm.label(address(oracles[AddrMarketPendle.sUSDe_31_07_25]), "Oracle LP sUSDe 31_07_25");

    //     // Oracle LP eUSDE 29_05_25
    //     oracles[AddrMarketPendle.eUSDe_29_05_25] = new OraclePendleLP(AddrMarketPendle.eUSDe_29_05_25, oracles[AddrClassicERC20.USDe]);
    //     vm.label(address(oracles[AddrMarketPendle.eUSDe_29_05_25]), "Oracle LP eUSDe 29_05_25");

    //     // Oracle LP eBTC 26_06_25
    //     oracles[AddrMarketPendle.eBTC_26_06_25] = new OraclePendleLP(AddrMarketPendle.eBTC_26_06_25, oracles[AddrClassicERC20.eBTC]);
    //     vm.label(address(oracles[AddrMarketPendle.eBTC_26_06_25]), "Oracle LP eBTC 26_06_25");
    // }
}
