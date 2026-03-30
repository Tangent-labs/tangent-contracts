import { PENDLE_POOLS, thiefConfig, CURVE_LPS } from "@tangent/defi-resources";

export function TOKENS_TO_GIVE_WITH_LP(mintedAmount: number) {
    const obj = thiefConfig.THIEF_TOKEN_CONFIG;

    const pendlePTconfig = {
        slotBalance: 0,
        decimals: 18,
        isVyper: false,
    };
    return [
        // USG
        {
            ...obj.CRV_USDC_USDT,
            amount: mintedAmount,
            name: "USDC_USDT",
        },
        {
            ...obj.CRV_frxUSD_USDe,
            amount: mintedAmount,
            name: "frxUSD_USDe",
        },
        {
            ...obj.frxETH_ETH,
            amount: mintedAmount,
            name: "frxETH_WETH",
        },
        {
            ...obj.pxETH_stETH,
            amount: mintedAmount,
            name: "pxETH_stETH",
        },
        {
            ...obj.cbBTC_WBTC,
            amount: mintedAmount,
            name: "cbBTC_WBTC",
        },
        // {
        //     ...obj.TRICRYPTO_USDC,
        //     amount: mintedAmount,
        //     name: "USDC-WBTC-WETH",
        // },
        // {
        //     ...obj.TRICRV,
        //     amount: mintedAmount,
        //     name: "crvUSD_ETH_CRV",
        // },
        // {
        //     ...obj.GHO_CBBTC_ETH,
        //     amount: mintedAmount,
        //     name: "GHO_cbBTC_WETH",
        // },
        // {
        //     ...obj.TRICRYPTO_USDT,
        //     amount: mintedAmount,
        //     name: "USDT_WBTC_WETH",
        // },
        // {
        //     ...obj.CRV_USR_RLP,
        //     amount: mintedAmount,
        //     name: "USR_RLP",
        // },
        {
            ...pendlePTconfig,
            address: PENDLE_POOLS["sUSDe 07/05/26"].PT,
            amount: mintedAmount,
            name: "sUSDe 07/05/26",
        },
        {
            ...pendlePTconfig,
            address: PENDLE_POOLS["USDe 07/05/26"].PT,
            amount: mintedAmount,
            name: "USDe 07/05/26",
        },
        {
            ...pendlePTconfig,
            address: PENDLE_POOLS["wstUSR 25/06/26"]?.PT,
            amount: mintedAmount,
            name: "wstUSR 25/06/26",
        },

        {
            ...obj.WETH,
            amount: mintedAmount,
            name: "WETH",
        },
        {
            ...obj.USDC,
            amount: mintedAmount,
            name: "USDC",
        },
        {
            ...obj.USDT,
            amount: mintedAmount,
            name: "USDT",
        },
        {
            ...obj.crvUSD,
            amount: mintedAmount,
            name: "crvUSD",
        },
        {
            ...obj.frxUSD,
            amount: mintedAmount,
            name: "frxUSD",
        },
        {
            ...obj.USR,
            amount: mintedAmount,
            name: "USR",
        },
        {
            ...obj.pxETH,
            amount: mintedAmount,
            name: "pxETH",
        },
        {
            ...obj.DOLA,
            amount: mintedAmount,
            name: "DOLA",
        },
        {
            ...obj.USDe,
            amount: mintedAmount,
            name: "USDe",
        },
        {
            ...obj.fxUSD,
            amount: mintedAmount,
            name: "fxUSD",
        },
        {
            ...obj.GHO,
            amount: mintedAmount,
            name: "GHO",
        },
        {
            ...obj.PYUSD,
            amount: mintedAmount,
            name: "PYUSD",
        },

        {
            ...obj.RLUSD,
            amount: mintedAmount,
            name: "RLUSD",
        },
        {
            ...obj.frxETH,
            amount: mintedAmount,
            name: "frxETH",
        },
        {
            ...obj.crvUSD_USDC,
            amount: mintedAmount,
            name: "crvUSD_USDC",
        },
        {
            ...obj.crvUSD_USDT,
            amount: mintedAmount,
            name: "crvUSD_USDT",
        },
        {
            ...obj.pxETH_WETH,
            amount: mintedAmount,
            name: "pxETH_WETH",
        },
        {
            ...obj.WETH_frxETH,
            amount: mintedAmount,
            name: "WETH_frxETH",
        },
        {
            ...obj.USDC_fxUSD,
            amount: mintedAmount,
            name: "USDC_fxUSD",
        },
        // {
        //     ...obj.CVX_ETH,
        //     amount: mintedAmount,
        //     name: "CVX_ETH",
        // },

        // Curve Gauge LP tokens
        {
            slotBalance: 38,
            decimals: 18,
            isVyper: true,
            address: CURVE_LPS.DUO_PYUSD_USDC,
            amount: mintedAmount,
            name: "PYUSD_USDC",
        },
        {
            slotBalance: 38,
            decimals: 18,
            isVyper: true,
            address: CURVE_LPS.DUO_RLUSD_USDC,
            amount: mintedAmount,
            name: "RLUSD_USDC",
        },
        {
            slotBalance: 0,
            decimals: 18,
            isVyper: false,
            address: CURVE_LPS.DUO_stUSDS_USDS,
            amount: mintedAmount,
            name: "stUSDS_USDS",
        },

        // StakeDao Vault LP tokens (Curve LP tokens)
        {
            slotBalance: 0,
            decimals: 18,
            isVyper: false,
            address: CURVE_LPS.DUO_frxUSD_msUSD,
            amount: mintedAmount,
            name: "frxUSD_msUSD",
        },
        {
            slotBalance: 0,
            decimals: 18,
            isVyper: false,
            address: CURVE_LPS.DUO_ETHplus_WETH,
            amount: mintedAmount,
            name: "ETH+_WETH",
        },
        {
            slotBalance: 0,
            decimals: 18,
            isVyper: false,
            address: CURVE_LPS.DUO_tBTC_cbBTC,
            amount: mintedAmount,
            name: "tBTC_cbBTC",
        },
        {
            slotBalance: 0,
            decimals: 18,
            isVyper: false,
            address: CURVE_LPS.DUO_msETH_OETH,
            amount: mintedAmount,
            name: "msETH_OETH",
        },

        // BOOSTERS
        {
            ...obj.CRV,
            amount: mintedAmount,
            name: "CRV",
        },
        {
            ...obj.sd_CRV,
            amount: mintedAmount,
            name: "sd_CRV",
        },

        {
            ...obj.PENDLE,
            amount: mintedAmount,
            name: "PENDLE",
        },
        {
            ...obj.sd_PENDLE,
            amount: mintedAmount,
            name: "sd_PENDLE",
        },

        {
            ...obj.BAL,
            amount: mintedAmount,
            name: "BAL",
        },
        {
            ...obj._80_BAL_20_WETH,
            amount: mintedAmount,
            name: "_80_BAL_20_WETH",
        },
        {
            ...obj.sd_BAL,
            amount: mintedAmount,
            name: "sd_BAL",
        },

        {
            ...obj.FXN,
            amount: mintedAmount,
            name: "FXN",
        },
        {
            ...obj.sd_FXN,
            amount: mintedAmount,
            name: "sd_FXN",
        },

        // LOCKERS

        {
            ...obj.SDT,
            amount: mintedAmount,
            name: "SDT",
        },
        {
            ...obj.YFI,
            amount: mintedAmount,
        },
        {
            ...obj.PENDLE,
            amount: mintedAmount,
        },
        {
            ...obj.RSUP,
            amount: mintedAmount,
        },
        {
            ...obj.CVX,
            amount: mintedAmount,
            name: "CVX",
        },
    ];
}
