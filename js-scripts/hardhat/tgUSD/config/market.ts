import {commonERC20, curveLp} from "convergence-defi-tools";
import {parseEther} from "ethers";

export const STATIC_CONFIG_CONVEX_CURVE = {
    crvUSD_USDC_Cvx_Market: {
        collatToken: curveLp.CRVUSD_USDC,
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.CRV, commonERC20.CVX],
        cvxRewardToken: "0x44D8FaB7CD8b7877D5F79974c2F501aF6E65AbBA",
        pid: 182,
    },
};
export const STATIC_CONFIG_CONVEX_FXN = {
    USDC_fxUSD_Cvx_Market: {
        collatToken: "0x5018BE882DccE5E3F2f3B0913AE2096B9b3fB61f",
        liquidationThreshold: 93_000,
        maxLTV: 85_000,
        maxMarketDebt: parseEther("1000000"),
        minimumLoan: parseEther("3000"),
        rewards: [commonERC20.FXN, commonERC20.CRV, commonERC20.CVX],
        pid: 32,
    },
};
