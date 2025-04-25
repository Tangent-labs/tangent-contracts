// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TgUSDDeployContext.sol";

import {OracleCoinFromCurveLP} from "../../../src/tgUSD/Oracles/Token/OracleCoinFromCurveLP.sol";
import {OracleERC4626} from "../../../src/tgUSD/Oracles/Token/OracleERC4626.sol";

import {OracleDuoPoolStable} from "../../../src/tgUSD/Oracles/CurveLP/OracleDuoPoolStable.sol";
import {OracleTriPoolStable} from "../../../src/tgUSD/Oracles/CurveLP/OracleTriPoolStable.sol";
import {OracleCryptoSwap} from "../../../src/tgUSD/Oracles/CurveLP/OracleCryptoSwap.sol";

import {OraclePendlePT} from "../../../src/tgUSD/Oracles/Pendle/OraclePendlePT.sol";

import {IRCalculator} from "../../../src/tgUSD/Utilities/IRCalculator.sol";
import {IAggregatorStablePriceV3} from "../../../src/interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";
import {IPegKeeperRegulator} from "../../../src/interfaces/externals/LlamaLend/IPegKeeperRegulator.sol";
import {IPegKeeperV2} from "../../../src/interfaces/externals/LlamaLend/IPegKeeperV2.sol";

contract OraclesContext is TgUSDDeployContext {
    IRCalculator public irCalculator;
    mapping(IERC20 => IPriceOracle) public oracles;

    IAggregatorStablePriceV3 public tgUSDOracle;

    IPegKeeperRegulator public pegKeeperRegulator;

    IPegKeeperV2 public pegKeeperTgUSD_USDC;
    IPegKeeperV2 public pegKeeperTgUSD_frxUSD;

    constructor() {
        vm.startPrank(owner);
        // Oracle tgUSD

        tgUSDOracle = IAggregatorStablePriceV3(deployCode("AggregatorStablePriceV3", abi.encode(tgUSD, uint256(1000000000000000), owner)));
        vm.label(address(tgUSDOracle), "Oracle tgUSD");

        irCalculator = new IRCalculator(owner, controlTower, tgUSDOracle, tgUSD);
        controlTower.toggleIRCalculator(address(irCalculator));

        rewardAccumulator = new RewardAccumulator(owner, controlTower, tgUSDOracle);

        vm.label(address(rewardAccumulator), "RewardAccumulator");

        marketCreator = new MarketCreator(
            owner,
            controlTower,
            tgUSD,
            irCalculator,
            rewardAccumulator,
            liquidatorProxy,
            convexCrvLPMarketImplem,
            convexFxnLPMarketImplem,
            marketNoSociabilizationImplem
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
    }

    function setupTgUSDOracle() public {
        vm.startPrank(owner);
        tgUSDOracle.add_price_pair(address(lpDeploymentContext.tgUSDLPs("tgUSD-USDC")));
        tgUSDOracle.add_price_pair(address(lpDeploymentContext.tgUSDLPs("tgUSD-wfrxUSD")));

        pegKeeperRegulator = IPegKeeperRegulator(deployCode("PegKeeperRegulator", abi.encode(tgUSD, tgUSDOracle, feeTreasury, owner, owner)));
        pegKeeperTgUSD_USDC = IPegKeeperV2(deployCode("PegKeeperV2", abi.encode(lpDeploymentContext.tgUSDLPs("tgUSD-USDC"), 20000, pegKeeperRegulator, owner)));
        pegKeeperTgUSD_frxUSD = IPegKeeperV2(deployCode("PegKeeperV2", abi.encode(lpDeploymentContext.tgUSDLPs("tgUSD-wfrxUSD"), 20000, pegKeeperRegulator, owner)));
        address[] memory pairs = new address[](2);
        pairs[0] = address(pegKeeperTgUSD_USDC);
        pairs[1] = address(pegKeeperTgUSD_frxUSD);

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
        oracles[AddrClassicERC20.CVX] = new OracleCoinFromCurveLP(address(AddrCryptoSwapLP.CVX_ETH), IPriceOracle(address(AddrChainlinkOracle.ETH)), false);
        vm.label(address(oracles[AddrClassicERC20.CVX]), "Oracle CVX");
    }

    function setupCurveTriCryptoSwapLPOracles() internal {
        // Oracle USDT_WBTC_ETH
        oracles[AddrCryptoSwapLP.USDT_WBTC_ETH] = new OracleCryptoSwap(AddrCryptoSwapLP.USDT_WBTC_ETH, AddrChainlinkOracle.USDT);
        vm.label(address(oracles[AddrCryptoSwapLP.USDT_WBTC_ETH]), "Oracle LP USDT/WBTC/ETH");

        // Oracle USDC_WBTC_ETH
        oracles[AddrCryptoSwapLP.USDC_WBTC_ETH] = new OracleCryptoSwap(AddrCryptoSwapLP.USDC_WBTC_ETH, AddrChainlinkOracle.USDC);
        vm.label(address(oracles[AddrCryptoSwapLP.USDC_WBTC_ETH]), "Oracle LP USDC/WBTC/ETH");

        // Oracle CRVUSD_ETH_CRV
        oracles[AddrCryptoSwapLP.crvUSD_ETH_CRV] = new OracleCryptoSwap(AddrCryptoSwapLP.crvUSD_ETH_CRV, AddrChainlinkOracle.crvUSD);
        vm.label(address(oracles[AddrCryptoSwapLP.crvUSD_ETH_CRV]), "Oracle LP crvUSD/ETH/CRV");

        // Oracle GHO_CBBTC_ETH
        oracles[AddrCryptoSwapLP.GHO_cbBTC_ETH] = new OracleCryptoSwap(AddrCryptoSwapLP.GHO_cbBTC_ETH, AddrChainlinkOracle.GHO);
        vm.label(address(oracles[AddrCryptoSwapLP.GHO_cbBTC_ETH]), "Oracle LP GHO/cbBTC/ETH");

        // Oracle USR_RLP
        oracles[AddrCryptoSwapLP.USR_RLP] = new OracleCryptoSwap(AddrCryptoSwapLP.USR_RLP, AddrChainlinkOracle.USR);
        vm.label(address(oracles[AddrCryptoSwapLP.USR_RLP]), "Oracle LP USR/RLP");

        // Oracle CVX_ETH
        oracles[AddrCryptoSwapLP.CVX_ETH] = new OracleCryptoSwap(AddrCryptoSwapLP.CVX_ETH, AddrChainlinkOracle.ETH);
        vm.label(address(oracles[AddrCryptoSwapLP.CVX_ETH]), "Oracle LP CVX/ETH");
    }

    function setupCurveStableLPOracles() internal {
        // Oracle CRVUSD_USDC
        oracles[AddrCurveStableLP.USDC_crvUSD] = new OracleDuoPoolStable(
            AddrCurveStableLP.USDC_crvUSD,
            IPriceOracle(address(AddrChainlinkOracle.USDC)),
            IPriceOracle(address(AddrChainlinkOracle.crvUSD))
        );
        vm.label(address(oracles[AddrCurveStableLP.USDC_crvUSD]), "Oracle LP crvUSD/USDC");

        // Oracle CRVUSD_USDT
        oracles[AddrCurveStableLP.USDT_crvUSD] = new OracleDuoPoolStable(
            AddrCurveStableLP.USDT_crvUSD,
            IPriceOracle(address(AddrChainlinkOracle.USDT)),
            IPriceOracle(address(AddrChainlinkOracle.crvUSD))
        );
        vm.label(address(oracles[AddrCurveStableLP.USDT_crvUSD]), "Oracle LP crvUSD/USDT");

        // Oracle USDC_FXUSD
        oracles[AddrCurveStableLP.USDC_fxUSD] = new OracleDuoPoolStable(
            AddrCurveStableLP.USDC_fxUSD,
            IPriceOracle(address(AddrChainlinkOracle.USDC)),
            oracles[AddrClassicERC20.fxUSD]
        );
        vm.label(address(oracles[AddrCurveStableLP.USDC_fxUSD]), "Oracle LP USDC/fxUSD");

        // Oracle TriStable DAI/USDC/USDT
        oracles[AddrCurveStableLP.TRI_USD_TOKEN] = new OracleTriPoolStable(
            AddrCurveStableLP.TRI_USD_LP,
            IPriceOracle(address(AddrChainlinkOracle.DAI)),
            IPriceOracle(address(AddrChainlinkOracle.USDC)),
            IPriceOracle(address(AddrChainlinkOracle.USDT))
        );
        vm.label(address(oracles[AddrCurveStableLP.TRI_USD_TOKEN]), "Oracle LP TriUSD");

        // Oracle frxETH/WETH
        oracles[AddrCurveStableLP.WETH_frxETH] = new OracleDuoPoolStable(
            AddrCurveStableLP.WETH_frxETH,
            IPriceOracle(address(AddrChainlinkOracle.ETH)),
            oracles[AddrClassicERC20.frxETH]
        );
        vm.label(address(oracles[AddrCurveStableLP.WETH_frxETH]), "Oracle LP frxETH/ETH");

        // Oracle pxETH/WETH
        oracles[AddrCurveStableLP.WETH_pxETH] = new OracleDuoPoolStable(
            AddrCurveStableLP.WETH_pxETH,
            IPriceOracle(address(AddrChainlinkOracle.ETH)),
            oracles[AddrClassicERC20.pxETH]
        );
        vm.label(address(oracles[AddrCurveStableLP.WETH_pxETH]), "Oracle LP pxETH/ETH");
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
        oracles[AddrPTPendle.sUSDe_31_07_25] = new OraclePendlePT(AddrMarketPendle.sUSDe_31_07_25, oracles[AddrClassicERC20.USDe]);
        vm.label(address(oracles[AddrPTPendle.sUSDe_31_07_25]), "Oracle PT sUSDe 31_07_25");

        // Oracle PT eUSDE 29_05_25
        oracles[AddrPTPendle.eUSDe_29_05_25] = new OraclePendlePT(AddrMarketPendle.eUSDe_29_05_25, oracles[AddrClassicERC20.USDe]);
        vm.label(address(oracles[AddrPTPendle.eUSDe_29_05_25]), "Oracle PT eUSDe 29_05_25");

        // Oracle PT eBTC 26_06_25
        oracles[AddrPTPendle.eBTC_26_06_25] = new OraclePendlePT(AddrMarketPendle.eBTC_26_06_25, oracles[AddrClassicERC20.eBTC]);
        vm.label(address(oracles[AddrPTPendle.eBTC_26_06_25]), "Oracle PT eBTC 26_06_25");
    }
}
