import {thiefConfig} from "defi-resources";

export function TOKENS_TO_GIVE_WITHOUT_LP(mintedAmount: number) {
    const obj = thiefConfig.THIEF_TOKEN_CONFIG;
    return [
        // USG
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
            ...obj.frxUSD,
            amount: mintedAmount,
        },
        {
            ...obj.USR,
            amount: mintedAmount,
        },
        {
            ...obj.pxETH,
            amount: mintedAmount,
        },
        {
            ...obj.DOLA,
            amount: mintedAmount,
        },
        {
            ...obj.USDe,
            amount: mintedAmount,
        },
        {
            ...obj.fxUSD,
            amount: mintedAmount,
        },
        {
            ...obj.GHO,
            amount: mintedAmount,
        },
        {
            ...obj.frxETH,
            amount: mintedAmount,
        },
    ];
}
