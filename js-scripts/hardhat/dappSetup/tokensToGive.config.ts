import {thiefConfig} from "convergence-defi-tools";

export function TOKENS_TO_GIVE(mintedAmount: bigint) {
    return [
        // BOOSTERS
        {
            token: thiefConfig.THIEF_TOKEN_CONFIG.CRV,
            amount: mintedAmount,
        },
        {
            token: thiefConfig.THIEF_TOKEN_CONFIG.sd_CRV,
            amount: mintedAmount,
        },

        {
            token: thiefConfig.THIEF_TOKEN_CONFIG.PENDLE,
            amount: mintedAmount,
        },
        {
            token: thiefConfig.THIEF_TOKEN_CONFIG.sd_PENDLE,
            amount: mintedAmount,
        },

        {
            token: thiefConfig.THIEF_TOKEN_CONFIG.BAL,
            amount: mintedAmount,
        },
        {
            token: thiefConfig.THIEF_TOKEN_CONFIG._80_BAL_20_WETH,
            amount: mintedAmount,
        },
        {
            token: thiefConfig.THIEF_TOKEN_CONFIG.sd_BAL,
            amount: mintedAmount,
        },

        {
            token: thiefConfig.THIEF_TOKEN_CONFIG.FXN,
            amount: mintedAmount,
        },
        {
            token: thiefConfig.THIEF_TOKEN_CONFIG.sd_FXN,
            amount: mintedAmount,
        },

        // LOCKERS

        {
            token: thiefConfig.THIEF_TOKEN_CONFIG.SDT,
            amount: mintedAmount,
        },

        {
            token: thiefConfig.THIEF_TOKEN_CONFIG.CVX,
            amount: mintedAmount,
        },
    ];
}
