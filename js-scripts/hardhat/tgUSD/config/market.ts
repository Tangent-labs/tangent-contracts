import {commonERC20, convexCrv, convexFxn, curveLp} from "convergence-defi-tools";
import {parseEther} from "ethers";

export const STATIC_CONFIG_CONVEX_CURVE = {
    crvUSD_USDC_Cvx_Market: {
        collatName: "crvUSD_USDC",
        collatToken: convexCrv.CRVUSD_USDC.lp,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: convexCrv.CRVUSD_USDC.cvxRewardToken,
        pid: convexCrv.CRVUSD_USDC.pid,
    },
    crvUSD_USDT_Cvx_Market: {
        collatName: "crvUSD_USDT",
        collatToken: convexCrv.CRVUSD_USDT.lp,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: convexCrv.CRVUSD_USDT.cvxRewardToken,
        pid: convexCrv.CRVUSD_USDT.pid,
    },
    frxETH_WETH_Cvx_Market: {
        collatName: "frxETH_WETH",
        collatToken: convexCrv.frxETH_WETH.lp,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: convexCrv.frxETH_WETH.cvxRewardToken,
        pid: convexCrv.frxETH_WETH.pid,
    },
    pxETH_WETH_Cvx_Market: {
        collatName: "pxETH_WETH",
        collatToken: convexCrv.pxETH_WETH.lp,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: convexCrv.pxETH_WETH.cvxRewardToken,
        pid: convexCrv.pxETH_WETH.pid,
    },
};
export const STATIC_CONFIG_CONVEX_FXN = {
    USDC_fxUSD_Cvx_Market: {
        collatName: "USDC_fxUSD",
        collatToken: convexFxn.USDC_fxUSD.lp,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.FXN, commonERC20.CRV, commonERC20.CVX],
        pid: convexFxn.USDC_fxUSD.pid,
    },
};
