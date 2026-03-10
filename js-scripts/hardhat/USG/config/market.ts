import { COMMON_ERC20S, ConvexCrvPools, ConvexFxnPools, CURVE_LPS, PENDLE_POOLS, CURVE_GAUGES, CURVE_CONTEXT } from "@tangent/defi-resources";
import { parseEther } from "ethers";
import { IRParamsStruct, RCParamsStruct } from "../../../../typechain-types/src/chainview/USG/GetMarketDetails.sol/GetMarketDetails";

// HEC
export const HEC_CONFIG_IR_PARAMS: IRParamsStruct = {
    isHEC: true,
    rMin: 0,
    rMax: 160_000,
    pMin: 980_000,
    pInf: 992_500,
    pMax: 995_000,
    a1: 1_500,
    a2: 1_500,
    k: 300,
};

export const HEC_CONFIG_RC_PARAMS: RCParamsStruct = {
    harvestFeePercentage: 1_000,
    startCutPercentage: 50_000,
    endCutPercentage: 100_000,
    stepAmount: 6,
    startCutPrice: 999_000,
    endCutPrice: 995_000,
};

// LEC
export const LEC_CONFIG_IR_PARAMS: IRParamsStruct = {
    isHEC: false,
    rMin: 2_500,
    rMax: 160_000,
    pMin: 980_000,
    pMax: 1_000_000,
    pInf: 997_500,
    a1: 1_900,
    a2: 2_750,
    k: 300,
};

export const LEC_CONFIG_RC_PARAMS: RCParamsStruct = {
    harvestFeePercentage: 1_000,
    startCutPercentage: 5_000,
    endCutPercentage: 0,
    stepAmount: 1,
    startCutPrice: 0,
    endCutPrice: 0,
};

export const STATIC_CONFIG_CONVEX_CURVE = {
    // STABLES
    crvUSD_USDC: {
        collatName: "crvUSD_USDC",
        collatToken: ConvexCrvPools.USDC_crvUSD.lpToken,
        liquidationThreshold: 91_500,
        maxLTV: 91_400,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX],
        pid: ConvexCrvPools.USDC_crvUSD.pid,
    },
    crvUSD_USDT: {
        collatName: "crvUSD_USDT",
        collatToken: ConvexCrvPools.USDT_crvUSD.lpToken,
        liquidationThreshold: 94_000,
        maxLTV: 93_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX],
        pid: ConvexCrvPools.USDT_crvUSD.pid,
    },
    USDC_USDT: {
        collatName: "USDC_USDT",
        collatToken: ConvexCrvPools.USDC_USDT_STRATEGICR.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 92_500,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX],
        pid: ConvexCrvPools.USDC_USDT_STRATEGICR.pid,
    },
    frxUSD_USDe: {
        collatName: "frxUSD_USDe",
        collatToken: ConvexCrvPools.frxUSD_USDe.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 92_500,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX],
        pid: ConvexCrvPools.frxUSD_USDe.pid,
    },
    // ETH STABLE
    frxETH_WETH: {
        collatName: "frxETH_WETH",
        collatToken: ConvexCrvPools.WETH_frxETH.lpToken,
        liquidationThreshold: 85_000,
        maxLTV: 84_900,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX],
        pid: ConvexCrvPools.WETH_frxETH.pid,
    },
    pxETH_WETH: {
        collatName: "pxETH_WETH",
        collatToken: ConvexCrvPools.WETH_pxETH.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 92_500,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX],
        pid: ConvexCrvPools.WETH_pxETH.pid,
    },

    pxETH_stETH: {
        collatName: "pxETH_stETH",
        collatToken: ConvexCrvPools.pxETH_stETH.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX],
        pid: ConvexCrvPools.pxETH_stETH.pid,
    },

    cbBTC_WBTC: {
        collatName: "cbBTC_WBTC",
        collatToken: ConvexCrvPools.cbBTC_WBTC.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX],
        pid: ConvexCrvPools.cbBTC_WBTC.pid,
    },
    // TRI CRYPTO
    USDT_WBTC_WETH: {
        collatName: "USDT_WBTC_WETH",
        collatToken: ConvexCrvPools.USDT_WBTC_WETH.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX],
        pid: ConvexCrvPools.USDT_WBTC_WETH.pid,
    },
    USDC_WBTC_WETH: {
        collatName: "USDC_WBTC_WETH",
        collatToken: ConvexCrvPools.USDC_WBTC_WETH.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX],
        pid: ConvexCrvPools.USDC_WBTC_WETH.pid,
    },
    crvUSD_ETH_CRV: {
        collatName: "crvUSD_ETH_CRV",
        collatToken: ConvexCrvPools.crvUSD_ETH_CRV.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX],
        pid: ConvexCrvPools.crvUSD_ETH_CRV.pid,
    },
    GHO_cbBTC_WETH: {
        collatName: "GHO_cbBTC_WETH",
        collatToken: ConvexCrvPools.GHO_cbBTC_WETH.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX],
        pid: ConvexCrvPools.GHO_cbBTC_WETH.pid,
    },

    // DUO CRYPTO

    CVX_ETH: {
        collatName: "CVX_ETH",
        collatToken: ConvexCrvPools.CVX_ETH.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX],
        pid: ConvexCrvPools.CVX_ETH.pid,
    },
    USR_RLP: {
        collatName: "USR_RLP",
        collatToken: ConvexCrvPools.USR_RLP.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX],
        pid: ConvexCrvPools.USR_RLP.pid,
    },
};
export const STATIC_CONFIG_CONVEX_FXN = {
    USDC_fxUSD: {
        collatName: "USDC_fxUSD",
        collatToken: ConvexFxnPools.USDC_fxUSD.lpToken,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX, COMMON_ERC20S.FXN],
        pid: ConvexFxnPools.USDC_fxUSD.pid,
    },
    GHO_fxUSD: {
        collatName: "GHO_fxUSD",
        collatToken: ConvexFxnPools.GHO_fxUSD.lpToken,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX, COMMON_ERC20S.FXN],
        pid: ConvexFxnPools.GHO_fxUSD.pid,
    },
    fxUSD_reUSD: {
        collatName: "fxUSD_reUSD",
        collatToken: ConvexFxnPools.fxUSD_reUSD.lpToken,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX, COMMON_ERC20S.FXN],
        pid: ConvexFxnPools.fxUSD_reUSD.pid,
    },
    msUSD_fxUSD: {
        collatName: "msUSD_fxUSD",
        collatToken: ConvexFxnPools.msUSD_fxUSD.lpToken,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX, COMMON_ERC20S.FXN],
        pid: ConvexFxnPools.msUSD_fxUSD.pid,
    },
};

export const STATIC_CONFIG_CURVE_GAUGE = {
    PYUSD_USDC: {
        collatName: "PYUSD_USDC",
        collatToken: CURVE_LPS.DUO_PYUSD_USDC,
        liquidationThreshold: 91_500,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.PYUSD],
        gaugeToken: CURVE_GAUGES.PYUSD_USDC,
    },
    RLUSD_USDC: {
        collatName: "RLUSD_USDC",
        collatToken: CURVE_LPS.DUO_RLUSD_USDC,
        liquidationThreshold: 91_500,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.RLUSD, COMMON_ERC20S.CRV],
        gaugeToken: CURVE_GAUGES.RLUSD_USDC,
    },

    stUSDS_USDS: {
        collatName: "stUSDS_USDS",
        collatToken: CURVE_LPS.DUO_stUSDS_USDS,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.USDS],
        gaugeToken: CURVE_GAUGES.stUSDS_USDS,
    },
};

export const STATIC_CONFIG_STAKEDAO_VAULT_V2 = {
    crvUSD_USDC: {
        collatName: "crvUSD_USDC",
        collatToken: ConvexCrvPools.USDC_crvUSD.lpToken,
        liquidationThreshold: 91_500,
        maxLTV: 91_400,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX],
        vaultToken: CURVE_CONTEXT.CURVE_CONTEXT.USDC_crvUSD.stakeDaoVault,
    },
    crvUSD_USDT: {
        collatName: "crvUSD_USDT",
        collatToken: ConvexCrvPools.USDT_crvUSD.lpToken,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV, COMMON_ERC20S.CVX],
        vaultToken: CURVE_CONTEXT.CURVE_CONTEXT.USDT_crvUSD.stakeDaoVault,
    },
    GHO_crvUSD: {
        collatName: "GHO_crvUSD",
        collatToken: ConvexCrvPools.USDT_crvUSD.lpToken,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV],
        vaultToken: CURVE_CONTEXT.CURVE_CONTEXT.USDT_crvUSD.stakeDaoVault,
    },
    reUSD_sfrxUSD: {
        collatName: "reUSD_sfrxUSD",
        collatToken: ConvexCrvPools.reUSD_sfrxUSD.lpToken,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV],
        vaultToken: CURVE_CONTEXT.CURVE_CONTEXT.reUSD_sfrxUSD.stakeDaoVault,
    },
    frxUSD_msUSD: {
        collatName: "frxUSD_msUSD",
        collatToken: ConvexCrvPools.frxUSD_msUSD.lpToken,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV],
        vaultToken: CURVE_CONTEXT.CURVE_CONTEXT.frxUSD_msUSD.stakeDaoVault,
    },
    ETHPlus_WETH: {
        collatName: "ETH+_WETH",
        collatToken: ConvexCrvPools.ETHPlus_WETH.lpToken,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV],
        vaultToken: CURVE_CONTEXT.CURVE_CONTEXT.ETHPlus_WETH.stakeDaoVault,
    },
    tBTC_cbBTC: {
        collatName: "tBTC_cbBTC",
        collatToken: ConvexCrvPools.tBTC_cbBTC.lpToken,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV],
        vaultToken: CURVE_CONTEXT.CURVE_CONTEXT.tBTC_cbBTC.stakeDaoVault,
    },
    msETH_OETH: {
        collatName: "msETH_OETH",
        collatToken: ConvexCrvPools.msETH_OETH.lpToken,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [COMMON_ERC20S.CRV],
        vaultToken: CURVE_CONTEXT.CURVE_CONTEXT.msETH_OETH.stakeDaoVault,
    },
};

export const STATIC_CONFIG_BASIC_ERC20s = {
    
    "Pendle PT - sUSDe 05/02/26": {
        collatName: "sUSDe 05/02/26",
        collatToken: PENDLE_POOLS["sUSDe 05/02/26"].PT,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("2000000"),
        minimumLoan: parseEther("3000"),
        rewardTokens: [],
    },
    


};
