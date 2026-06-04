import { COMMON_ERC20S, ConvexFxnPools, CURVE_GAUGES, CURVE_LPS, PENDLE_POOLS } from "@tangent/defi-resources";
import { parseEther } from "ethers";
import { IR_PARAMS_LEC_USD_A, IR_PARAMS_LEC_USD_S } from "./irParams";
import { RC_PARAMS_LEC_USD_S_A_B } from "./rcParams";


export type MarketConfig = {
    collatName: string;
    collatToken: string;
    liquidationThreshold: number;
    maxLTV: number;
    maxMarketDebt: bigint;
    minimumLoan: bigint
    rewardTokens: string[],
    collatDecimals?: number
    logo?: string
}



export const MINIMUM_LOAN = parseEther("2000")

export type USGMarketType = "Convex_CRV" | "Convex_FXN" | "Pendle_PT" | "STAKEDAO_CRV_Vault" | "CRV_Gauge"


export const STATIC_CONFIG_CONVEX_FXN = {
    USDC_fxUSD: {
        collatName: "USDC/fxUSD",
        collatToken: ConvexFxnPools.USDC_fxUSD.lpToken,
        liquidationThreshold: 91_250,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("500000"),
        minimumLoan: MINIMUM_LOAN,
        rewardTokens: [COMMON_ERC20S.FXN],
        pid: ConvexFxnPools.USDC_fxUSD.pid,
        irConfig: IR_PARAMS_LEC_USD_A,
        rcConfig: RC_PARAMS_LEC_USD_S_A_B
    },
    fxUSD_reUSD: {
        collatName: "fxUSD/reUSD",
        collatToken: ConvexFxnPools.fxUSD_reUSD.lpToken,
        liquidationThreshold: 85_000,
        maxLTV: 84_000,
        maxMarketDebt: parseEther("250000"),
        minimumLoan: MINIMUM_LOAN,
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.FXN],
        pid: ConvexFxnPools.fxUSD_reUSD.pid,
        irConfig: IR_PARAMS_LEC_USD_S,
        rcConfig: RC_PARAMS_LEC_USD_S_A_B
    },

};

export const STATIC_CONFIG_CURVE_GAUGE = {
    PYUSD_USDC: {
        collatName: "PYUSD/USDC",
        collatToken: CURVE_LPS.DUO_PYUSD_USDC,
        liquidationThreshold: 91_500,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("2000"),
        rewardTokens: [COMMON_ERC20S.PYUSD],
        gaugeToken: CURVE_GAUGES.PYUSD_USDC,
        irConfig: IR_PARAMS_LEC_USD_S,
        rcConfig: RC_PARAMS_LEC_USD_S_A_B
    },
    RLUSD_USDC: {
        collatName: "RLUSD/USDC",
        collatToken: CURVE_LPS.DUO_RLUSD_USDC,
        liquidationThreshold: 91_500,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: MINIMUM_LOAN,
        rewardTokens: [COMMON_ERC20S.RLUSD, COMMON_ERC20S.CRV],
        gaugeToken: CURVE_GAUGES.RLUSD_USDC,
        irConfig: IR_PARAMS_LEC_USD_S,
        rcConfig: RC_PARAMS_LEC_USD_S_A_B
    }
};




export const STATIC_CONFIG_BASIC_ERC20s =
{
    "sUSDe 08/13/2026": {
        collatName: "sUSDe 08/13/2026",
        collatToken: PENDLE_POOLS["sUSDe 08/13/2026"].PT,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: MINIMUM_LOAN,
        rewardTokens: [],
        logo: "PT_USDe"
    }
};
