import {thiefConfig} from "convergence-defi-tools";

export function TOKENS_TO_GIVE(mintedAmount: number) {
    return [
        // BOOSTERS
        {
            ...thiefConfig.THIEF_TOKEN_CONFIG.CRV,
            amount: mintedAmount,
        },
        {
            ...thiefConfig.THIEF_TOKEN_CONFIG.sd_CRV,
            amount: mintedAmount,
        },

        {
            ...thiefConfig.THIEF_TOKEN_CONFIG.PENDLE,
            amount: mintedAmount,
        },
        {
            ...thiefConfig.THIEF_TOKEN_CONFIG.sd_PENDLE,
            amount: mintedAmount,
        },

        {
            ...thiefConfig.THIEF_TOKEN_CONFIG.BAL,
            amount: mintedAmount,
        },
        {
            ...thiefConfig.THIEF_TOKEN_CONFIG._80_BAL_20_WETH,
            amount: mintedAmount,
        },
        {
            ...thiefConfig.THIEF_TOKEN_CONFIG.sd_BAL,
            amount: mintedAmount,
        },

        {
            ...thiefConfig.THIEF_TOKEN_CONFIG.FXN,
            amount: mintedAmount,
        },
        {
            ...thiefConfig.THIEF_TOKEN_CONFIG.sd_FXN,
            amount: mintedAmount,
        },

        // LOCKERS

        {
            ...thiefConfig.THIEF_TOKEN_CONFIG.SDT,
            amount: mintedAmount,
        },

        {
            ...thiefConfig.THIEF_TOKEN_CONFIG.CVX,
            amount: mintedAmount,
        },

        // tgUSD
        {
            ...thiefConfig.THIEF_TOKEN_CONFIG.USDC,
            amount: mintedAmount,
        },
        {
            ...thiefConfig.THIEF_TOKEN_CONFIG.CRVUSD,
            amount: mintedAmount,
        },
        {
            ...thiefConfig.THIEF_TOKEN_CONFIG.CRVUSD_USDC,
            amount: mintedAmount,
        },
    ];
}
