import { CHAINLINK_PRICE_FEEDS } from "@tangent/defi-resources";
import { REDSTONE_PRICE_FEEDS } from "@tangent/defi-resources";

import { ONE_YEAR_IN_SECONDS } from "@tangent/defi-resources/build/utils/durations";
import { ZeroAddress } from "ethers";

export const chainlinkOracleParams: {
    key: string;
    oracleName: keyof typeof CHAINLINK_PRICE_FEEDS;
    heatbeat: number
    oracleAggregator: string;
    fallbackKey: string;
}[] = [
        // Stable USD
        { key: "crvUSD", oracleName: "crvUSD_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.crvUSD_USD, fallbackKey: ZeroAddress },
        { key: "USDC", oracleName: "USDC_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.USDC_USD, fallbackKey: "USDC_USD_RED" },
        { key: "FRAX", oracleName: "FRAX_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.FRAX_USD, fallbackKey: ZeroAddress },
        { key: "USDT", oracleName: "USDT_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.USDT_USD, fallbackKey: "USDT_USD_RED" },
        { key: "USR", oracleName: "USR_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.USR_USD, fallbackKey: "USR_USR_RED" },
        { key: "GHO", oracleName: "GHO_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.GHO_USD, fallbackKey: ZeroAddress },
        { key: "USDe", oracleName: "USDe_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.USDe_USD, fallbackKey: "USDe_USD_RED" },

        { key: "PYUSD", oracleName: "PYUSD_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.PYUSD_USD, fallbackKey: ZeroAddress },
        { key: "RLUSD", oracleName: "RLUSD_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.RLUSD_USD, fallbackKey: ZeroAddress },
        // ETH
        { key: "ETH", oracleName: "ETH_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.ETH_USD, fallbackKey: "ETH_USD_RED" },
        { key: "stETH", oracleName: "stETH_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.stETH_USD, fallbackKey: ZeroAddress },
        // BTC
        // { key: "BTC", oracleName: "BTC_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.BTC_USD, fallbackKey: ZeroAddress },
        { key: "cbBTC", oracleName: "cbBTC_USD", heatbeat: ONE_YEAR_IN_SECONDS, oracleAggregator: CHAINLINK_PRICE_FEEDS.cbBTC_USD, fallbackKey: ZeroAddress },
    ];

export const redstonOracles: {
    key: string;
    oracleName: keyof typeof REDSTONE_PRICE_FEEDS;
    bytesKey: string
}[] = [
        // Stable USD
        { key: "ETH_USD_RED", oracleName: "ETH_USD", bytesKey: REDSTONE_PRICE_FEEDS.ETH_USD },
        { key: "USDC_USD_RED", oracleName: "USDC_USD", bytesKey: REDSTONE_PRICE_FEEDS.USDC_USD },
        { key: "USDT_USD_RED", oracleName: "USDT_USD", bytesKey: REDSTONE_PRICE_FEEDS.USDT_USD },
        { key: "USDe_USD_RED", oracleName: "USDe_USD", bytesKey: REDSTONE_PRICE_FEEDS.USDe_USD },
        { key: "USR_USD_RED", oracleName: "USR_USD", bytesKey: REDSTONE_PRICE_FEEDS.USR_USD },
    ];

export const oracleERC4626Params = [
    { erc4626: "sUSDe", oracleName: 'sUSDe / USD', underlyingOracle: "USDe" },
    { erc4626: "wstUSR", oracleName: 'wstUSR / USD', underlyingOracle: "USR" },
];

export const oracleCoinFromCurveLPParams = [
    { key: "frxUSD", oracleName: 'frxUSD / USD', lp: "CRV_DUO_FRAX_frxUSD", coin0Oracle: "FRAX", isReversed: 0 },
    { key: "fxUSD", oracleName: 'fxUSD / USD', lp: "CRV_LP_USDC_fxUSD", coin0Oracle: "USDC", isReversed: 0 },
    { key: "frxETH", oracleName: 'frxETH / USD', lp: "CRV_LP_WETH_frxETH", coin0Oracle: "ETH", isReversed: 0 },
    { key: "pxETH", oracleName: 'pxETH / USD', lp: "CRV_LP_pxETH_WETH", coin0Oracle: "ETH", isReversed: 0 },
];

export const oracleDuoPoolStableParams = [
    // USD
    { key: "crvUSD_USDC", oracleName: "crvUSD_USDC / USD", lp: "crvUSD_USDC", coin0Oracle: "USDC", coin1Oracle: "crvUSD" },
    { key: "crvUSD_USDT", oracleName: "crvUSD_USDT / USD", lp: "crvUSD_USDT", coin0Oracle: "USDT", coin1Oracle: "crvUSD" },
    { key: "USDC_fxUSD", oracleName: "USDC_fxUSD / USD", lp: "CRV_LP_USDC_fxUSD", coin0Oracle: "USDC", coin1Oracle: "fxUSD" },
    { key: "USDC_USDT", oracleName: "USDC_USDT / USD", lp: "CRV_DUO_USDC_USDT", coin0Oracle: "USDC", coin1Oracle: "USDT" },
    { key: "frxUSD_USDe", oracleName: "frxUSD_USDe / USD", lp: "CRV_DUO_frxUSD_USDe", coin0Oracle: "frxUSD", coin1Oracle: "USDe" },
    { key: "RLUSD_USDC", oracleName: "RLUSD_USDC / USD", lp: "CRV_DUO_RLUSD_USDC", coin0Oracle: "PYUSD", coin1Oracle: "USDC" },
    { key: "PYUSD_USDC", oracleName: "PYUSD_USDC / USD", lp: "CRV_DUO_PYUSD_USDC", coin0Oracle: "RLUSD", coin1Oracle: "USDC" },
    // ETH
    { key: "frxETH_WETH", oracleName: "frxETH_WETH / USD", lp: "CRV_LP_WETH_frxETH", coin0Oracle: "ETH", coin1Oracle: "frxETH" },
    { key: "pxETH_WETH", oracleName: "pxETH_WETH / USD", lp: "CRV_LP_pxETH_WETH", coin0Oracle: "ETH", coin1Oracle: "ETH" },
    { key: "pxETH_stETH", oracleName: "pxETH_stETH / USD", lp: "CRV_LP_pxETH_stETH", coin0Oracle: "pxETH", coin1Oracle: "stETH" },
    // BTC
    // { key: "cbBTC_WBTC", lp: "CRV_DUO_cbBTC_WBTC", coin0Oracle: "cbBTC", coin1Oracle: "BTC" },
];

export const oracleCryptoSwapParams = [
    // TRI
    { key: "USDT-WBTC-WETH", lp: "CRV_TRI_CRYPTO_USDT", coin0Oracle: "USDT" },
    { key: "USDC-WBTC-WETH", lp: "CRV_TRI_CRYPTO_USDC", coin0Oracle: "USDC" },
    { key: "crvUSD-ETH-CRV", lp: "CRV_TRI_CRYPTO_CRV", coin0Oracle: "crvUSD" },
    { key: "GHO-cbBTC-WETH", lp: "CRV_TRI_GHO_cbBTC_ETH", coin0Oracle: "GHO" },
    // DUO
    { key: "CVX-ETH", lp: "CRV_DUO_ETH_CVX", coin0Oracle: "ETH" },
    { key: "USR-RLP", lp: "CRV_DUO_USR_RLP", coin0Oracle: "USR" },
];

export const oraclePendlePTParams = [
    { key: "sUSDe 27/11/25", oracleName: "PT sUSDe_27_11_25 / USD", underlyingOracle: "sUSDe" },
    { key: "USDe 27/11/25", oracleName: "PT USDe_27_11_25 / USD", underlyingOracle: "USDe" },
];