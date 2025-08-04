// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./USGDeployContext.sol";

import {OracleCoinFromCurveLP} from "../../src/USG/Oracles/Token/OracleCoinFromCurveLP.sol";
import {OracleERC4626} from "../../src/USG/Oracles/Token/OracleERC4626.sol";

import {OracleDuoPoolStable} from "../../src/USG/Oracles/CurveLP/OracleDuoPoolStable.sol";
import {OracleTriPoolStable} from "../../src/USG/Oracles/CurveLP/OracleTriPoolStable.sol";
import {OracleCryptoSwap} from "../../src/USG/Oracles/CurveLP/OracleCryptoSwap.sol";

import {OraclePendlePT} from "../../src/USG/Oracles/Pendle/OraclePendlePT.sol";
import {OraclePendleLP} from "../../src/USG/Oracles/Pendle/OraclePendleLP.sol";

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
    IPegKeeperV2 public pegKeeperUSG_frxUSD;

    constructor() {
        vm.startPrank(owner);
        // Oracle USG

        USGOracle = IAggregatorStablePriceV3(deployCode("AggregatorStablePriceV3", abi.encode(usg, uint256(1000000000000000), owner)));
        vm.label(address(USGOracle), "Oracle USG");

        irCalculator = new IRCalculator(owner, controlTower, USGOracle, usg);
        controlTower.toggleIRCalculator(address(irCalculator));

        rewardAccumulator = new RewardAccumulator(owner, controlTower, USGOracle);

        vm.label(address(rewardAccumulator), "RewardAccumulator");

        marketCreator = new MarketCreator(
            owner,
            controlTower,
            usg,
            irCalculator,
            rewardAccumulator,
            zappingProxy,
            pauser,
            convexCrvLPMarketImplem,
            convexFxnLPMarketImplem,
            marketBasicERC20Implem
        );
        controlTower.toggleMarketCreator(address(marketCreator));
        vm.label(address(marketCreator), "MarketCreator");

        vm.stopPrank();
        setupChainlinkOracles();
        setupSimpleTokenOraclesWithCurveLP();
        setupSavingAccountOracles();
        setupCurveStableLPOracles();
        setupCurveTriCryptoSwapLPOracles();
        setupPendlePTTokens();
        setupPendleLPTokens();
    }

    function setupUSGOracle() public {
        vm.startPrank(owner);
        USGOracle.add_price_pair(address(lpDeploymentContext.USGLPs("USG-USDC")));
        USGOracle.add_price_pair(address(lpDeploymentContext.USGLPs("USG-wfrxUSD")));

        pegKeeperRegulator = IPegKeeperRegulator(deployCode("PegKeeperRegulator", abi.encode(usg, USGOracle, feeTreasury, owner, owner)));
        pegKeeperUSG_USDC = IPegKeeperV2(deployCode("PegKeeperV2", abi.encode(lpDeploymentContext.USGLPs("USG-USDC"), 20000, pegKeeperRegulator, owner)));
        pegKeeperUSG_frxUSD = IPegKeeperV2(deployCode("PegKeeperV2", abi.encode(lpDeploymentContext.USGLPs("USG-wfrxUSD"), 20000, pegKeeperRegulator, owner)));

        controlTower.togglePegKeeper(address(pegKeeperUSG_USDC));
        controlTower.togglePegKeeper(address(pegKeeperUSG_frxUSD));

        address[] memory pairs = new address[](2);
        pairs[0] = address(pegKeeperUSG_USDC);
        pairs[1] = address(pegKeeperUSG_frxUSD);

        pegKeeperRegulator.add_peg_keepers(pairs);
        vm.stopPrank();
    }

    function setupChainlinkOracles() internal {
        oracles[AddrClassicERC20.DAI] = IPriceOracle(AddrChainlinkOracle.DAI);
        vm.label(address(AddrChainlinkOracle.DAI), "Oracle DAI");

        oracles[AddrClassicERC20.USDS] = IPriceOracle(AddrChainlinkOracle.USDS);
        vm.label(address(AddrChainlinkOracle.USDS), "Oracle USDS");

        oracles[AddrClassicERC20.USDe] = IPriceOracle(AddrChainlinkOracle.USDe);
        vm.label(address(AddrChainlinkOracle.USDe), "Oracle USDe");

        oracles[AddrClassicERC20.USDC] = IPriceOracle(AddrChainlinkOracle.USDC);
        vm.label(address(AddrChainlinkOracle.USDC), "Oracle USDC");

        oracles[AddrClassicERC20.USDT] = IPriceOracle(AddrChainlinkOracle.USDT);
        vm.label(address(AddrChainlinkOracle.USDT), "Oracle USDT");

        oracles[AddrClassicERC20.crvUSD] = IPriceOracle(AddrChainlinkOracle.crvUSD);
        vm.label(address(AddrChainlinkOracle.crvUSD), "Oracle crvUSD");

        oracles[AddrClassicERC20.GHO] = IPriceOracle(AddrChainlinkOracle.GHO);
        vm.label(address(AddrChainlinkOracle.GHO), "Oracle GHO");

        oracles[AddrClassicERC20.WETH] = IPriceOracle(AddrChainlinkOracle.ETH);
        vm.label(address(AddrChainlinkOracle.ETH), "Oracle ETH");

        oracles[AddrClassicERC20.WBTC] = IPriceOracle(AddrChainlinkOracle.BTC);
        vm.label(address(AddrChainlinkOracle.BTC), "Oracle BTC");

        oracles[AddrClassicERC20.cbBTC] = IPriceOracle(AddrChainlinkOracle.cbBTC);
        vm.label(address(AddrChainlinkOracle.cbBTC), "Oracle cbBTC");

        oracles[AddrClassicERC20.CRV] = IPriceOracle(AddrChainlinkOracle.CRV);
        vm.label(address(AddrChainlinkOracle.CRV), "Oracle CRV");

        // TODO Warning, is flagged as HIGH MARKET RISK
        oracles[AddrClassicERC20.USR] = IPriceOracle(AddrChainlinkOracle.USR);
        vm.label(address(AddrChainlinkOracle.USR), "Oracle USR");

        oracles[AddrClassicERC20.stETH] = IPriceOracle(AddrChainlinkOracle.stETH);
        vm.label(address(AddrChainlinkOracle.stETH), "Oracle stETH");
    }

    function setupSimpleTokenOraclesWithCurveLP() internal {
        // Oracle fxUSD
        oracles[AddrClassicERC20.fxUSD] = new OracleCoinFromCurveLP(address(AddrCurveStableLP.USDC_fxUSD), IPriceOracle(address(AddrChainlinkOracle.USDC)), false);
        vm.label(address(oracles[AddrClassicERC20.fxUSD]), "Oracle fxUSD");

        // Oracle DOLA
        oracles[AddrClassicERC20.DOLA] = new OracleCoinFromCurveLP(address(AddrCurveStableLP.DOLA_sUSDS), oracles[AddrClassicERC20.USDS], true);
        vm.label(address(oracles[AddrClassicERC20.DOLA]), "Oracle DOLA");

        // Oracle frxUSD
        oracles[AddrClassicERC20.frxUSD] = new OracleCoinFromCurveLP(address(AddrCurveStableLP.frxUSD_sUSDS), oracles[AddrClassicERC20.USDS], true);
        vm.label(address(oracles[AddrClassicERC20.frxUSD]), "Oracle frxUSD");

        // Oracle frxETH
        oracles[AddrClassicERC20.frxETH] = new OracleCoinFromCurveLP(address(AddrCurveStableLP.WETH_frxETH), IPriceOracle(address(AddrChainlinkOracle.ETH)), false);
        vm.label(address(oracles[AddrClassicERC20.frxETH]), "Oracle frxETH");

        // Oracle pxETH
        oracles[AddrClassicERC20.pxETH] = new OracleCoinFromCurveLP(address(AddrCurveStableLP.WETH_pxETH), IPriceOracle(address(AddrChainlinkOracle.ETH)), false);
        vm.label(address(oracles[AddrClassicERC20.pxETH]), "Oracle pxETH");

        // Oracle eBTC
        oracles[AddrClassicERC20.eBTC] = new OracleCoinFromCurveLP(address(AddrCurveStableLP.eBTC_WBTC), IPriceOracle(address(AddrChainlinkOracle.BTC)), true);
        vm.label(address(oracles[AddrClassicERC20.eBTC]), "Oracle eBTC");

        // Oracle RLP
        oracles[AddrClassicERC20.RLP] = new OracleCoinFromCurveLP(address(AddrCryptoSwapLP.USR_RLP), IPriceOracle(address(AddrChainlinkOracle.USR)), false);
        vm.label(address(oracles[AddrClassicERC20.RLP]), "Oracle RLP");

        // Oracle CVX
        oracles[AddrClassicERC20.CVX] = new OracleCoinFromCurveLP(address(AddrCryptoSwapLP.CVX_ETH_POOL), IPriceOracle(address(AddrChainlinkOracle.ETH)), false);
        vm.label(address(oracles[AddrClassicERC20.CVX]), "Oracle CVX");
    }

    function setupCurveTriCryptoSwapLPOracles() internal {
        // Oracle USDT_WBTC_ETH
        oracles[AddrCryptoSwapLP.USDT_WBTC_ETH] = new OracleCryptoSwap(address(AddrCryptoSwapLP.USDT_WBTC_ETH), AddrChainlinkOracle.USDT);
        vm.label(address(oracles[AddrCryptoSwapLP.USDT_WBTC_ETH]), "Oracle LP USDT/WBTC/ETH");

        // Oracle USDC_WBTC_ETH
        oracles[AddrCryptoSwapLP.USDC_WBTC_ETH] = new OracleCryptoSwap(address(AddrCryptoSwapLP.USDC_WBTC_ETH), AddrChainlinkOracle.USDC);
        vm.label(address(oracles[AddrCryptoSwapLP.USDC_WBTC_ETH]), "Oracle LP USDC/WBTC/ETH");

        // Oracle CRVUSD_ETH_CRV
        oracles[AddrCryptoSwapLP.crvUSD_ETH_CRV] = new OracleCryptoSwap(address(AddrCryptoSwapLP.crvUSD_ETH_CRV), AddrChainlinkOracle.crvUSD);
        vm.label(address(oracles[AddrCryptoSwapLP.crvUSD_ETH_CRV]), "Oracle LP crvUSD/ETH/CRV");

        // Oracle GHO_CBBTC_ETH
        oracles[AddrCryptoSwapLP.GHO_cbBTC_ETH] = new OracleCryptoSwap(address(AddrCryptoSwapLP.GHO_cbBTC_ETH), AddrChainlinkOracle.GHO);
        vm.label(address(oracles[AddrCryptoSwapLP.GHO_cbBTC_ETH]), "Oracle LP GHO/cbBTC/ETH");

        // Oracle USR_RLP
        oracles[AddrCryptoSwapLP.USR_RLP] = new OracleCryptoSwap(address(AddrCryptoSwapLP.USR_RLP), AddrChainlinkOracle.USR);
        vm.label(address(oracles[AddrCryptoSwapLP.USR_RLP]), "Oracle LP USR/RLP");

        // Oracle CVX_ETH
        oracles[AddrCryptoSwapLP.CVX_ETH_LP] = new OracleCryptoSwap(address(AddrCryptoSwapLP.CVX_ETH_POOL), AddrChainlinkOracle.ETH);
        vm.label(address(oracles[AddrCryptoSwapLP.CVX_ETH_LP]), "Oracle LP CVX/ETH");
    }

    function setupCurveStableLPOracles() internal {
        // Oracle CRVUSD_USDC
        oracles[AddrCurveStableLP.USDC_crvUSD] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.USDC_crvUSD),
            IPriceOracle(address(AddrChainlinkOracle.USDC)),
            IPriceOracle(address(AddrChainlinkOracle.crvUSD))
        );
        vm.label(address(oracles[AddrCurveStableLP.USDC_crvUSD]), "Oracle LP crvUSD/USDC");

        // Oracle CRVUSD_USDT
        oracles[AddrCurveStableLP.USDT_crvUSD] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.USDT_crvUSD),
            IPriceOracle(address(AddrChainlinkOracle.USDT)),
            IPriceOracle(address(AddrChainlinkOracle.crvUSD))
        );
        vm.label(address(oracles[AddrCurveStableLP.USDT_crvUSD]), "Oracle LP crvUSD/USDT");

        // Oracle USDC_FXUSD
        oracles[AddrCurveStableLP.USDC_fxUSD] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.USDC_fxUSD),
            IPriceOracle(address(AddrChainlinkOracle.USDC)),
            oracles[AddrClassicERC20.fxUSD]
        );
        vm.label(address(oracles[AddrCurveStableLP.USDC_fxUSD]), "Oracle LP USDC/fxUSD");

        // Oracle TriStable DAI/USDC/USDT
        oracles[AddrCurveStableLP.TRI_USD_LP] = new OracleTriPoolStable(
            address(AddrCurveStableLP.TRI_USD_POOL),
            IPriceOracle(address(AddrChainlinkOracle.DAI)),
            IPriceOracle(address(AddrChainlinkOracle.USDC)),
            IPriceOracle(address(AddrChainlinkOracle.USDT))
        );
        vm.label(address(oracles[AddrCurveStableLP.TRI_USD_LP]), "Oracle LP TriUSD");

        // Oracle frxETH/WETH
        oracles[AddrCurveStableLP.WETH_frxETH] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.WETH_frxETH),
            IPriceOracle(address(AddrChainlinkOracle.ETH)),
            oracles[AddrClassicERC20.frxETH]
        );
        vm.label(address(oracles[AddrCurveStableLP.WETH_frxETH]), "Oracle LP frxETH/ETH");

        // Oracle pxETH/WETH
        oracles[AddrCurveStableLP.WETH_pxETH] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.WETH_pxETH),
            IPriceOracle(address(AddrChainlinkOracle.ETH)),
            oracles[AddrClassicERC20.pxETH]
        );
        vm.label(address(oracles[AddrCurveStableLP.WETH_pxETH]), "Oracle LP pxETH/ETH");

        // Oracle ETH/stETH
        oracles[AddrCurveStableLP.ETH_stETH_LP] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.ETH_stETH_POOL),
            IPriceOracle(address(AddrChainlinkOracle.ETH)),
            oracles[AddrClassicERC20.stETH]
        );
        vm.label(address(oracles[AddrCurveStableLP.WETH_pxETH]), "Oracle LP ETH/stETH");

        // Oracle sDAI/sUSDe
        oracles[AddrCurveStableLP.sDAI_sUSDe] = new OracleDuoPoolStable(address(AddrCurveStableLP.sDAI_sUSDe), oracles[AddrClassicERC20.DAI], oracles[AddrClassicERC20.USDe]);
        vm.label(address(oracles[AddrCurveStableLP.sDAI_sUSDe]), "Oracle LP sDAI/sUSDe");

        // Oracle scrvUSD/sDOLA
        oracles[AddrCurveStableLP.scrvUSD_sDOLA] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.scrvUSD_sDOLA),
            oracles[AddrClassicERC20.crvUSD],
            oracles[AddrClassicERC20.DOLA]
        );
        vm.label(address(oracles[AddrCurveStableLP.scrvUSD_sDOLA]), "Oracle LP scrvUSD/sDOLA");

        // Oracle sUSDS/USDT
        oracles[AddrCurveStableLP.sUSDS_USDT] = new OracleDuoPoolStable(address(AddrCurveStableLP.sUSDS_USDT), oracles[AddrClassicERC20.USDS], oracles[AddrClassicERC20.USDT]);
        vm.label(address(oracles[AddrCurveStableLP.sUSDS_USDT]), "Oracle LP sUSDS/USDT");

        // Oracle cbBTC/WBTC
        oracles[AddrCurveStableLP.cbBTC_WBTC] = new OracleDuoPoolStable(address(AddrCurveStableLP.cbBTC_WBTC), oracles[AddrClassicERC20.cbBTC], oracles[AddrClassicERC20.WBTC]);
        vm.label(address(oracles[AddrCurveStableLP.cbBTC_WBTC]), "Oracle LP cbBTC/WBTC");

        // Oracle frxUSD/sUSDS
        oracles[AddrCurveStableLP.frxUSD_sUSDS] = new OracleDuoPoolStable(
            address(AddrCurveStableLP.frxUSD_sUSDS),
            oracles[AddrClassicERC20.frxUSD],
            oracles[AddrClassicERC20.USDS]
        );
        vm.label(address(oracles[AddrCurveStableLP.frxUSD_sUSDS]), "Oracle LP frxUSD/sUSDS");
    }

    function setupSavingAccountOracles() internal {
        // Oracle sDAI
        oracles[AddrERC4626.sDAI] = new OracleERC4626(AddrERC4626.sDAI, oracles[AddrClassicERC20.DAI]);
        vm.label(address(oracles[AddrERC4626.sDAI]), "Oracle sDAI");
        // Oracle sUSDS
        oracles[AddrERC4626.sUSDS] = new OracleERC4626(AddrERC4626.sUSDS, oracles[AddrClassicERC20.USDS]);
        vm.label(address(oracles[AddrERC4626.sUSDS]), "Oracle sUSDS");
        // Oracle sUSDe
        oracles[AddrERC4626.sUSDe] = new OracleERC4626(AddrERC4626.sUSDe, oracles[AddrClassicERC20.USDe]);
        vm.label(address(oracles[AddrERC4626.sUSDe]), "Oracle sUSDe");
        // Oracle sDOLA
        oracles[AddrERC4626.sDOLA] = new OracleERC4626(AddrERC4626.sDOLA, oracles[AddrClassicERC20.DOLA]);
        vm.label(address(oracles[AddrERC4626.sDOLA]), "Oracle sDOLA");
        // Oracle scrvUSD
        oracles[AddrERC4626.scrvUSD] = new OracleERC4626(AddrERC4626.scrvUSD, oracles[AddrClassicERC20.crvUSD]);
        vm.label(address(oracles[AddrERC4626.scrvUSD]), "Oracle scrvUSD");
        // Oracle wstUSR
        oracles[AddrERC4626.wstUSR] = new OracleERC4626(AddrERC4626.wstUSR, oracles[AddrClassicERC20.USR]);
        vm.label(address(oracles[AddrERC4626.wstUSR]), "Oracle wstUSR");
        // Oracle sfrxUSD
        oracles[AddrERC4626.sfrxUSD] = new OracleERC4626(AddrERC4626.sfrxUSD, oracles[AddrClassicERC20.frxUSD]);
        vm.label(address(oracles[AddrERC4626.sfrxUSD]), "Oracle sfrxUSD");
    }

    function setupPendlePTTokens() internal {
        // Oracle PT sUSDE 31_07_25
        oracles[AddrPTPendle.sUSDe_31_07_25] = new OraclePendlePT(AddrMarketPendle.sUSDe_31_07_25, oracles[AddrERC4626.sUSDe], 900);
        vm.label(address(oracles[AddrPTPendle.sUSDe_31_07_25]), "Oracle PT sUSDe 31_07_25");

        // Oracle PT eUSDE 29_05_25
        oracles[AddrPTPendle.eUSDe_29_05_25] = new OraclePendlePT(AddrMarketPendle.eUSDe_29_05_25, oracles[AddrClassicERC20.USDe], 900);
        vm.label(address(oracles[AddrPTPendle.eUSDe_29_05_25]), "Oracle PT eUSDe 29_05_25");

        // Oracle PT eBTC 26_06_25
        oracles[AddrPTPendle.eBTC_26_06_25] = new OraclePendlePT(AddrMarketPendle.eBTC_26_06_25, oracles[AddrClassicERC20.eBTC], 900);
        vm.label(address(oracles[AddrPTPendle.eBTC_26_06_25]), "Oracle PT eBTC 26_06_25");

        // Oracle PT wstUSR_25_09_25
        oracles[AddrPTPendle.wstUSR_25_09_25] = new OraclePendlePT(AddrMarketPendle.wstUSR_25_09_25, oracles[AddrERC4626.wstUSR], 900);
        vm.label(address(oracles[AddrPTPendle.wstUSR_25_09_25]), "Oracle PT wstUSR_25_09_25");

        // Oracle PT sUSDe_25_09_25
        oracles[AddrPTPendle.sUSDe_25_09_25] = new OraclePendlePT(AddrMarketPendle.sUSDe_25_09_25, oracles[AddrERC4626.sUSDe], 900);
        vm.label(address(oracles[AddrPTPendle.sUSDe_25_09_25]), "Oracle PT sUSDe_25_09_25");

        // Oracle PT USDe_25_09_25
        oracles[AddrPTPendle.USDe_25_09_25] = new OraclePendlePT(AddrMarketPendle.USDe_25_09_25, oracles[AddrClassicERC20.USDe], 900);
        vm.label(address(oracles[AddrPTPendle.USDe_25_09_25]), "Oracle PT USDe_25_09_25");

        // Oracle PT USR_04_09_25
        oracles[AddrPTPendle.USR_04_09_25] = new OraclePendlePT(AddrMarketPendle.USR_04_09_25, oracles[AddrClassicERC20.USR], 900);
        vm.label(address(oracles[AddrPTPendle.USR_04_09_25]), "Oracle PT USR_04_09_25");
    }

    function setupPendleLPTokens() internal {
        // Oracle LP sUSDE 31_07_25
        oracles[AddrMarketPendle.sUSDe_31_07_25] = new OraclePendleLP(AddrMarketPendle.sUSDe_31_07_25, oracles[AddrClassicERC20.USDe]);
        vm.label(address(oracles[AddrMarketPendle.sUSDe_31_07_25]), "Oracle LP sUSDe 31_07_25");

        // Oracle LP eUSDE 29_05_25
        oracles[AddrMarketPendle.eUSDe_29_05_25] = new OraclePendleLP(AddrMarketPendle.eUSDe_29_05_25, oracles[AddrClassicERC20.USDe]);
        vm.label(address(oracles[AddrMarketPendle.eUSDe_29_05_25]), "Oracle LP eUSDe 29_05_25");

        // Oracle LP eBTC 26_06_25
        oracles[AddrMarketPendle.eBTC_26_06_25] = new OraclePendleLP(AddrMarketPendle.eBTC_26_06_25, oracles[AddrClassicERC20.eBTC]);
        vm.label(address(oracles[AddrMarketPendle.eBTC_26_06_25]), "Oracle LP eBTC 26_06_25");
    }
}
