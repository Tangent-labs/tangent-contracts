import { PRICE_FEEDS } from "@tangent/defi-resources";
import { ONE_YEAR_IN_SECONDS } from "@tangent/defi-resources/build/utils/durations";
import { ZeroAddress } from "ethers";

export const chainlinkOracleParams: {
    key: string;
    oracleName: keyof typeof PRICE_FEEDS;
    heatbeat: number
    fallback: string;
}[] = [
        // Stable USD
        { key: "crvUSD", oracleName: "crvUSD_USD", heatbeat: ONE_YEAR_IN_SECONDS, fallback: ZeroAddress },
        { key: "USDC", oracleName: "USDC_USD", heatbeat: ONE_YEAR_IN_SECONDS, fallback: ZeroAddress },
        { key: "FRAX", oracleName: "FRAX_USD", heatbeat: ONE_YEAR_IN_SECONDS, fallback: ZeroAddress },
        { key: "USDT", oracleName: "USDT_USD", heatbeat: ONE_YEAR_IN_SECONDS, fallback: ZeroAddress },
        { key: "USR", oracleName: "USR_USD", heatbeat: ONE_YEAR_IN_SECONDS, fallback: ZeroAddress },
        { key: "GHO", oracleName: "GHO_USD", heatbeat: ONE_YEAR_IN_SECONDS, fallback: ZeroAddress },
        { key: "USDe", oracleName: "USDe_USD", heatbeat: ONE_YEAR_IN_SECONDS, fallback: ZeroAddress },
        // ETH
        { key: "ETH", oracleName: "ETH_USD", heatbeat: ONE_YEAR_IN_SECONDS, fallback: ZeroAddress },
        { key: "stETH", oracleName: "stETH_USD", heatbeat: ONE_YEAR_IN_SECONDS, fallback: ZeroAddress },
        // BTC
        { key: "BTC", oracleName: "BTC_USD", heatbeat: ONE_YEAR_IN_SECONDS, fallback: ZeroAddress },
        { key: "cbBTC", oracleName: "cbBTC_USD", heatbeat: ONE_YEAR_IN_SECONDS, fallback: ZeroAddress },
    ];

export const oracleERC4626Params = [
    { erc4626: "sUSDe", underlyingOracle: "USDe" },
    { erc4626: "wstUSR", underlyingOracle: "USR" },
];

export const oracleCoinFromCurveLPParams = [
    { key: "frxUSD", lp: "CRV_DUO_FRAX_frxUSD", coin0Oracle: "FRAX", isReversed: false },
    { key: "fxUSD", lp: "CRV_LP_USDC_fxUSD", coin0Oracle: "USDC", isReversed: false },
    { key: "frxETH", lp: "CRV_LP_WETH_frxETH", coin0Oracle: "ETH", isReversed: false },
    { key: "pxETH", lp: "CRV_LP_pxETH_WETH", coin0Oracle: "ETH", isReversed: false },
];

export const oracleDuoPoolStableParams = [
    // USD
    { key: "crvUSD-USDC", lp: "crvUSD_USDC", coin0Oracle: "USDC", coin1Oracle: "crvUSD" },
    { key: "crvUSD-USDT", lp: "crvUSD_USDT", coin0Oracle: "USDT", coin1Oracle: "crvUSD" },
    { key: "USDC-fxUSD", lp: "CRV_LP_USDC_fxUSD", coin0Oracle: "USDC", coin1Oracle: "fxUSD" },
    { key: "USDC-USDT", lp: "CRV_DUO_USDC_USDT", coin0Oracle: "USDC", coin1Oracle: "USDT" },
    { key: "frxUSD-USDe", lp: "CRV_DUO_frxUSD_USDe", coin0Oracle: "frxUSD", coin1Oracle: "USDe" },
    // ETH
    { key: "frxETH-WETH", lp: "CRV_LP_WETH_frxETH", coin0Oracle: "ETH", coin1Oracle: "frxETH" },
    { key: "pxETH-WETH", lp: "CRV_LP_pxETH_WETH", coin0Oracle: "ETH", coin1Oracle: "ETH" },
    { key: "pxETH-stETH", lp: "CRV_LP_pxETH_stETH", coin0Oracle: "pxETH", coin1Oracle: "stETH" },
    // BTC
    { key: "cbBTC-WBTC", lp: "CRV_DUO_cbBTC_WBTC", coin0Oracle: "cbBTC", coin1Oracle: "BTC" },
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
    { key: "sUSDe 27/11/25", underlyingOracle: "sUSDe" },
    { key: "USDe 27/11/25", underlyingOracle: "USDe" },
];