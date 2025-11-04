import { commonERC20, ConvexCrvPools, ConvexFxnPools, PendlePools } from "@tangent/defi-resources";
import { parseEther } from "ethers";
import { IRParamsStruct, RCParamsStruct } from "../../../../typechain-types/src/chainview/USG/GetMarketDetails";

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
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: ConvexCrvPools.USDC_crvUSD.cvxRewardToken,
        pid: ConvexCrvPools.USDC_crvUSD.pid,
    },
    crvUSD_USDT: {
        collatName: "crvUSD_USDT",
        collatToken: ConvexCrvPools.USDT_crvUSD.lpToken,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: ConvexCrvPools.USDT_crvUSD.cvxRewardToken,
        pid: ConvexCrvPools.USDT_crvUSD.pid,
    },
    USDC_USDT: {
        collatName: "USDC_USDT",
        collatToken: ConvexCrvPools.USDC_USDT_STRATEGICR.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: ConvexCrvPools.USDC_USDT_STRATEGICR.cvxRewardToken,
        pid: ConvexCrvPools.USDC_USDT_STRATEGICR.pid,
    },
    frxUSD_USDe: {
        collatName: "frxUSD_USDe",
        collatToken: ConvexCrvPools.frxUSD_USDe.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: ConvexCrvPools.frxUSD_USDe.cvxRewardToken,
        pid: ConvexCrvPools.frxUSD_USDe.pid,
    },
    // ETH STABLE
    frxETH_WETH: {
        collatName: "frxETH_WETH",
        collatToken: ConvexCrvPools.WETH_frxETH.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: ConvexCrvPools.WETH_frxETH.cvxRewardToken,
        pid: ConvexCrvPools.WETH_frxETH.pid,
    },
    pxETH_WETH: {
        collatName: "pxETH_WETH",
        collatToken: ConvexCrvPools.WETH_pxETH.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: ConvexCrvPools.WETH_pxETH.cvxRewardToken,
        pid: ConvexCrvPools.WETH_pxETH.pid,
    },

    pxETH_stETH: {
        collatName: "pxETH_stETH",
        collatToken: ConvexCrvPools.pxETH_stETH.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: ConvexCrvPools.pxETH_stETH.cvxRewardToken,
        pid: ConvexCrvPools.pxETH_stETH.pid,
    },

    cbBTC_WBTC: {
        collatName: "cbBTC_WBTC",
        collatToken: ConvexCrvPools.cbBTC_WBTC.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: ConvexCrvPools.cbBTC_WBTC.cvxRewardToken,
        pid: ConvexCrvPools.cbBTC_WBTC.pid,
    },
    // TRI CRYPTO
    USDT_WBTC_WETH: {
        collatName: "USDT_WBTC_WETH",
        collatToken: ConvexCrvPools.USDT_WBTC_WETH.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: ConvexCrvPools.USDT_WBTC_WETH.cvxRewardToken,
        pid: ConvexCrvPools.USDT_WBTC_WETH.pid,
    },
    USDC_WBTC_WETH: {
        collatName: "USDC_WBTC_WETH",
        collatToken: ConvexCrvPools.USDC_WBTC_WETH.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: ConvexCrvPools.USDC_WBTC_WETH.cvxRewardToken,
        pid: ConvexCrvPools.USDC_WBTC_WETH.pid,
    },
    crvUSD_ETH_CRV: {
        collatName: "crvUSD_ETH_CRV",
        collatToken: ConvexCrvPools.crvUSD_ETH_CRV.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: ConvexCrvPools.crvUSD_ETH_CRV.cvxRewardToken,
        pid: ConvexCrvPools.crvUSD_ETH_CRV.pid,
    },
    GHO_cbBTC_WETH: {
        collatName: "GHO_cbBTC_WETH",
        collatToken: ConvexCrvPools.GHO_cbBTC_WETH.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: ConvexCrvPools.GHO_cbBTC_WETH.cvxRewardToken,
        pid: ConvexCrvPools.GHO_cbBTC_WETH.pid,
    },

    // DUO CRYPTO

    CVX_ETH: {
        collatName: "CVX_ETH",
        collatToken: ConvexCrvPools.CVX_ETH.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: ConvexCrvPools.CVX_ETH.cvxRewardToken,
        pid: ConvexCrvPools.CVX_ETH.pid,
    },
    USR_RLP: {
        collatName: "USR_RLP",
        collatToken: ConvexCrvPools.USR_RLP.lpToken,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: ConvexCrvPools.USR_RLP.cvxRewardToken,
        pid: ConvexCrvPools.USR_RLP.pid,
    },
};
export const STATIC_CONFIG_CONVEX_FXN = {
    USDC_fxUSD: {
        collatName: "USDC_fxUSD",
        collatToken: ConvexFxnPools.USDC_fxUSD.lpToken,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.FXN, commonERC20.CRV, commonERC20.CVX],
        pid: ConvexFxnPools.USDC_fxUSD.pid,
    },
};

export const STATIC_CONFIG_PT_PENDLE = {
    sUSDe_25_09_25: {
        collatName: "sUSDe 09/25/25",
        collatToken: PendlePools["sUSDe 09/25/25"].PT,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [],
    },

    USDe_25_09_25: {
        collatName: "USDe 09/25/25",
        collatToken: PendlePools["USDe 09/25/25"].PT,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [],
    },

    wstUSR_25_09_25: {
        collatName: "wstUSR 09/25/25",
        collatToken: PendlePools["wstUSR 09/25/25"].PT,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [],
    },

    USR_04_09_25: {
        collatName: "USR 09/04/25",
        collatToken: PendlePools["USR 09/04/25"].PT,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [],
    },
    sUSDe_27_11_25: {
        collatName: "sUSDe 27/11/25",
        collatToken: PendlePools["sUSDe 27/11/25"].PT,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [],
    },
    sUSDf_29_01_26: {
        collatName: "sUSDf 29/01/26",
        collatToken: PendlePools["sUSDf 29/01/26"].PT,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [],
    },
    USDe_27_11_25: {
        collatName: "USDe 27/11/25",
        collatToken: PendlePools["USDe 27/11/25"].PT,
        liquidationThreshold: 94_000,
        maxLTV: 90_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [],
    },

};
