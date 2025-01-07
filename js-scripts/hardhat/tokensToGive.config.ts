import {thiefConfig} from "convergence-defi-tools";

export function TOKENS_TO_GIVE(mintedAmount: number) {
    const obj = thiefConfig.THIEF_TOKEN_CONFIG;
    return [
        // tgUSD
        {
            ...obj.USDC,
            amount: mintedAmount,
        },
        {
            ...obj.USDT,
            amount: mintedAmount,
        },
        {
            ...obj.crvUSD,
            amount: mintedAmount,
        },
        {
            ...obj.fxUSD,
            amount: mintedAmount,
        },
        {
            ...obj.frxETH,
            amount: mintedAmount,
        },
        {
            ...obj.crvUSD_USDC,
            amount: mintedAmount,
        },
        {
            ...obj.crvUSD_USDT,
            amount: mintedAmount,
        },
        {
            ...obj.pxETH_WETH,
            amount: mintedAmount,
        },
        {
            ...obj.WETH_frxETH,
            amount: mintedAmount,
        },
        {
            ...obj.USDC_fxUSD,
            amount: mintedAmount,
        },

        // BOOSTERS
        {
            ...obj.CRV,
            amount: mintedAmount,
        },
        {
            ...obj.sd_CRV,
            amount: mintedAmount,
        },

        {
            ...obj.PENDLE,
            amount: mintedAmount,
        },
        {
            ...obj.sd_PENDLE,
            amount: mintedAmount,
        },

        {
            ...obj.BAL,
            amount: mintedAmount,
        },
        {
            ...obj._80_BAL_20_WETH,
            amount: mintedAmount,
        },
        {
            ...obj.sd_BAL,
            amount: mintedAmount,
        },

        {
            ...obj.FXN,
            amount: mintedAmount,
        },
        {
            ...obj.sd_FXN,
            amount: mintedAmount,
        },

        // LOCKERS

        {
            ...obj.SDT,
            amount: mintedAmount,
        },

        {
            ...obj.CVX,
            amount: mintedAmount,
        },
    ];
}
