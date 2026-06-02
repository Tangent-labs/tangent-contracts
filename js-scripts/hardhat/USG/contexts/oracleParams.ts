import { CHAINLINK_PRICE_FEEDS, COMMON_ERC20S, CURVE_LPS, PENDLE_POOLS, REDSTONE_PRICE_FEEDS } from "@tangent/defi-resources";

import { ONE_YEAR_IN_SECONDS } from "@tangent/defi-resources/build/utils/durations";
import { ZeroAddress } from "ethers";

export const chainlinkOracleParams: {
    key: keyof typeof COMMON_ERC20S;
    oracleName: keyof typeof CHAINLINK_PRICE_FEEDS;
    heatbeat: number;
    oracleAggregator: string;
    fallbackKey: string;
}[] = [
        // PROD
        { key: "USDC", oracleName: "USDC_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.USDC_USD, fallbackKey: "USDC_USD_RED" },
        { key: "USDT", oracleName: "USDT_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.USDT_USD, fallbackKey: "USDT_USD_RED" },
        { key: "USDe", oracleName: "USDe_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.USDe_USD, fallbackKey: "USDe_USD_RED" },
        { key: "PYUSD", oracleName: "PYUSD_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.PYUSD_USD, fallbackKey: "PYUSD_USD_RED" },
        { key: "RLUSD", oracleName: "RLUSD_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.RLUSD_USD, fallbackKey: ZeroAddress },
        { key: "crvUSD", oracleName: "crvUSD_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.crvUSD_USD, fallbackKey: ZeroAddress },
        { key: "frxUSD", oracleName: "frxUSD_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.frxUSD_USD, fallbackKey: ZeroAddress },
        { key: "USDS", oracleName: "USDS_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.USDS_USD, fallbackKey: ZeroAddress },


        // Stable USD
        { key: "FRAX", oracleName: "FRAX_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.FRAX_USD, fallbackKey: ZeroAddress },
        { key: "GHO", oracleName: "GHO_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.GHO_USD, fallbackKey: ZeroAddress },

        // ETH
        { key: "WETH", oracleName: "ETH_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.ETH_USD, fallbackKey: "ETH_USD_RED" },
        { key: "stETH", oracleName: "stETH_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.stETH_USD, fallbackKey: ZeroAddress },

        // BTC
        // { key: "BTC", oracleName: "BTC_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.BTC_USD, fallbackKey: ZeroAddress },
        { key: "cbBTC", oracleName: "cbBTC_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.cbBTC_USD, fallbackKey: ZeroAddress },
        { key: "tBTC", oracleName: "tBTC_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.tBTC_USD, fallbackKey: ZeroAddress },
    ];

export const redstonOracles: {
    key: string;
    oracleName: keyof typeof REDSTONE_PRICE_FEEDS;
    bytesKey: string;
}[] = [
        //PROD
        { key: "USDC_USD_RED", oracleName: "USDC_USD", bytesKey: REDSTONE_PRICE_FEEDS.USDC_USD },
        { key: "USDT_USD_RED", oracleName: "USDT_USD", bytesKey: REDSTONE_PRICE_FEEDS.USDT_USD },
        { key: "USDe_USD_RED", oracleName: "USDe_USD", bytesKey: REDSTONE_PRICE_FEEDS.USDe_USD },
        { key: "PYUSD_USD_RED", oracleName: "PYUSD_USD", bytesKey: REDSTONE_PRICE_FEEDS.PYUSD_USD },

        // Others
        { key: "ETH_USD_RED", oracleName: "ETH_USD", bytesKey: REDSTONE_PRICE_FEEDS.ETH_USD },

    ];

export const oracleERC4626Params: {
    erc4626: keyof typeof COMMON_ERC20S;
    oracleName: string;
    underlyingOracle: string;
}[] = [
        { erc4626: "sUSDe", oracleName: "sUSDe / USD", underlyingOracle: "USDe" },
        { erc4626: "scrvUSD", oracleName: "scrvUSD / USD", underlyingOracle: "crvUSD" },
    ];

export const oracleCoinFromCurveLPParams: {
    key: keyof typeof COMMON_ERC20S;
    oracleName: string;
    lp: keyof typeof CURVE_LPS;
    otherStableOracle: string;
    isReversed: number;
}[] = [
        // STABLES
        { key: "frxUSD", oracleName: "frxUSD / USD", lp: "DUO_FRAX_frxUSD", otherStableOracle: "FRAX", isReversed: 0 },
        { key: "fxUSD", oracleName: "fxUSD / USD", lp: "LP_USDC_fxUSD", otherStableOracle: "USDC", isReversed: 0 },
        { key: "msUSD", oracleName: "msUSD / USD", lp: "DUO_frxUSD_msUSD", otherStableOracle: "frxUSD", isReversed: 0 },
        { key: "BOLD", oracleName: "BOLD / USD", lp: "DUO_BOLD_USDC", otherStableOracle: "USDC", isReversed: 1 },
        { key: "OUSD", oracleName: "OUSD / USD", lp: "DUO_OUSD_USDC", otherStableOracle: "USDC", isReversed: 1 },
        { key: "eUSD", oracleName: "eUSD / USD", lp: "DUO_eUSD_USDC", otherStableOracle: "USDC", isReversed: 1 },

        { key: "reUSD", oracleName: "reUSD / USD", lp: "DUO_reUSD_sfrxUSD", otherStableOracle: "frxUSD", isReversed: 1 },
        { key: "eUSD", oracleName: "eUSD / USD", lp: "DUO_eUSD_USDC", otherStableOracle: "USDC", isReversed: 1 },
        { key: "DOLA", oracleName: "DOLA / USD", lp: "DUO_DOLA_sUSDS", otherStableOracle: "USDS", isReversed: 1 },

        { key: "stUSDS", oracleName: "stUSDS / USD", lp: "DUO_stUSDS_USDS", otherStableOracle: "USDS", isReversed: 1 }, // I'm not sure about this, as it's "coin0Oracle "

        // ETH
        { key: "ETH+", oracleName: "ETH+ / USD", lp: "DUO_ETHplus_WETH", otherStableOracle: "WETH", isReversed: 1 }, // I'm not sure about this, as it's "coin0Oracle "
        { key: "OETH", oracleName: "OETH / USD", lp: "DUO_OETH_WETH", otherStableOracle: "WETH", isReversed: 1 }, // I'm not sure about this, as it's "coin0Oracle "
        { key: "frxETH", oracleName: "frxETH / USD", lp: "LP_WETH_frxETH", otherStableOracle: "WETH", isReversed: 0 },
        { key: "pxETH", oracleName: "pxETH / USD", lp: "LP_pxETH_WETH", otherStableOracle: "WETH", isReversed: 0 },
        { key: "msETH", oracleName: "msETH / USD", lp: "DUO_msETH_WETH", otherStableOracle: "WETH", isReversed: 0 },
    ];

export const oracleDuoPoolStableParams: {
    key: string;
    oracleName: string;
    lp: keyof typeof CURVE_LPS;
    coin0Oracle: keyof typeof COMMON_ERC20S;
    coin1Oracle: keyof typeof COMMON_ERC20S;
}[] = [

        // PROD 
        { key: "frxUSD/sUSDS", oracleName: "frxUSD_sUSDS / USD", lp: "DUO_frxUSD_sUSDS", coin0Oracle: "frxUSD", coin1Oracle: "USDS" },
        { key: "BOLD/USDC", oracleName: "BOLD_USDC / USD", lp: "DUO_BOLD_USDC", coin0Oracle: "BOLD", coin1Oracle: "USDC" },
        { key: "frxUSD/OUSD", oracleName: "frxUSD_OUSD / USD", lp: "DUO_frxUSD_OUSD", coin0Oracle: "frxUSD", coin1Oracle: "OUSD" },
        { key: "frxUSD/msUSD", oracleName: "frxUSD_msUSD / USD", lp: "DUO_frxUSD_msUSD", coin0Oracle: "frxUSD", coin1Oracle: "msUSD" },
        { key: "reUSD/sfrxUSD", oracleName: "reUSD_sfrxUSD / USD", lp: "DUO_reUSD_sfrxUSD", coin0Oracle: "reUSD", coin1Oracle: "frxUSD" },
        { key: "reUSD/scrvUSD", oracleName: "reUSD_scrvUSD / USD", lp: "DUO_reUSD_scrvUSD", coin0Oracle: "reUSD", coin1Oracle: "scrvUSD" },
        { key: "frxUSD/crvUSD", oracleName: "frxUSD_crvUSD / USD", lp: "DUO_crvUSD_frxUSD", coin0Oracle: "frxUSD", coin1Oracle: "crvUSD" },
        { key: "PYUSD/USDC", oracleName: "PYUSD_USDC / USD", lp: "DUO_PYUSD_USDC", coin0Oracle: "PYUSD", coin1Oracle: "USDC" },
        { key: "RLUSD/USDC", oracleName: "RLUSD_USDC / USD", lp: "DUO_RLUSD_USDC", coin0Oracle: "USDC", coin1Oracle: "RLUSD" },
        { key: "USDC/fxUSD", oracleName: "USDC_fxUSD / USD", lp: "LP_USDC_fxUSD", coin0Oracle: "USDC", coin1Oracle: "fxUSD" },
        { key: "frxUSD/OUSD", oracleName: "frxUSD_OUSD / USD", lp: "DUO_frxUSD_OUSD", coin0Oracle: "frxUSD", coin1Oracle: "fxUSD" },
        { key: "eUSD/USDC", oracleName: "eUSD_USDC / USD", lp: "DUO_eUSD_USDC", coin0Oracle: "eUSD", coin1Oracle: "USDC" },
        { key: "frxUSD/sDOLA", oracleName: "frxUSD_sDOLA / USD", lp: "DUO_frxUSD_sDOLA", coin0Oracle: "frxUSD", coin1Oracle: "DOLA" },
        { key: "frxUSD/scrvUSD", oracleName: "frxUSD_scrvUSD / USD", lp: "DUO_frxUSD_scrvUSD", coin0Oracle: "frxUSD", coin1Oracle: "crvUSD" },

        // USD
        { key: "crvUSD/USDC", oracleName: "crvUSD_USDC / USD", lp: "crvUSD_USDC", coin0Oracle: "USDC", coin1Oracle: "crvUSD" },
        { key: "USDT/crvUSD", oracleName: "USDT_crvUSD / USD", lp: "crvUSD_USDT", coin0Oracle: "USDT", coin1Oracle: "crvUSD" },
        { key: "USDC/USDT", oracleName: "USDC_USDT / USD", lp: "DUO_USDC_USDT", coin0Oracle: "USDC", coin1Oracle: "USDT" },
        { key: "frxUSD/USDe", oracleName: "frxUSD_USDe / USD", lp: "DUO_frxUSD_USDe", coin0Oracle: "frxUSD", coin1Oracle: "USDe" },
        { key: "GHO/crvUSD", oracleName: "GHO_crvUSD / USD", lp: "DUO_GHO_crvUSD", coin0Oracle: "GHO", coin1Oracle: "crvUSD" }, //Verify coin order

        { key: "GHO/fxUSD", oracleName: "GHO_fxUSD / USD", lp: "DUO_GHO_fxUSD", coin0Oracle: "GHO", coin1Oracle: "fxUSD" }, //Verify coin order
        { key: "fxUSD/reUSD", oracleName: "fxUSD_reUSD / USD", lp: "DUO_fxUSD_reUSD", coin0Oracle: "fxUSD", coin1Oracle: "reUSD" }, //Verify coin order
        { key: "msUSD/fxUSD", oracleName: "msUSD_fxUSD / USD", lp: "DUO_msUSD_fxUSD", coin0Oracle: "msUSD", coin1Oracle: "fxUSD" }, //Verify coin order
        { key: "stUSDS/USDS", oracleName: "stUSDS_USDS / USD", lp: "DUO_stUSDS_USDS", coin0Oracle: "stUSDS", coin1Oracle: "USDS" }, //Verify coin order

        // ETH
        { key: "frxETH/WETH", oracleName: "frxETH_WETH / USD", lp: "LP_WETH_frxETH", coin0Oracle: "WETH", coin1Oracle: "frxETH" },
        { key: "pxETH/WETH", oracleName: "pxETH_WETH / USD", lp: "LP_pxETH_WETH", coin0Oracle: "WETH", coin1Oracle: "WETH" },
        { key: "pxETH/stETH", oracleName: "pxETH_stETH / USD", lp: "LP_pxETH_stETH", coin0Oracle: "pxETH", coin1Oracle: "stETH" },
        { key: "ETH+/WETH", oracleName: "ETH+_WETH / USD", lp: "DUO_ETHplus_WETH", coin0Oracle: "ETH+", coin1Oracle: "WETH" }, //Verify coin order
        { key: "msETH/OETH", oracleName: "msETH_OETH / USD", lp: "DUO_msETH_OETH", coin0Oracle: "msETH", coin1Oracle: "OETH" }, // Verify coin order

        // BTC
        { key: "tBTC/cbBTC", oracleName: "tBTC_cbBTC / USD", lp: "DUO_tBTC_cbBTC", coin0Oracle: "tBTC", coin1Oracle: "cbBTC" },
    ];

export const oracleCryptoSwapParams = [
    // TRI
    { key: "USDT-WBTC-WETH", lp: "CRV_TRI_CRYPTO_USDT", coin0Oracle: "USDT" },
    { key: "USDC-WBTC-WETH", lp: "CRV_TRI_CRYPTO_USDC", coin0Oracle: "USDC" },
    { key: "crvUSD-ETH-CRV", lp: "CRV_TRI_CRYPTO_CRV", coin0Oracle: "crvUSD" },
    { key: "GHO-cbBTC-WETH", lp: "CRV_TRI_GHO_cbBTC_ETH", coin0Oracle: "GHO" },
    // DUO
    { key: "CVX-ETH", lp: "CRV_DUO_ETH_CVX", coin0Oracle: "WETH" },
];

export const oraclePendlePTParams: {
    key: keyof typeof PENDLE_POOLS;
    oracleName: string;
    underlyingOracle: string;
    decimalsDelta: number;
}[] = [
        // { key: "sUSDe 05/02/26", oracleName: "sUSDe_05_02_26 / USD", underlyingOracle: "sUSDe", decimalsDelta: 18 },
        // { key: "wstETH 25/06/26", oracleName: "PT wstETH 25_06_26 / USD", underlyingOracle: "wstETH" },
        { key: "USDe 07/05/26", oracleName: "PT USDe 07/05/26 / USD", underlyingOracle: "USDe", decimalsDelta: 18 },
        { key: "sUSDe 07/05/26", oracleName: "PT sUSDe 07/05/26 / USD", underlyingOracle: "sUSDe", decimalsDelta: 18 },
    ];
