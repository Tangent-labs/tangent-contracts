import {
    depositCurveLP,
    withdrawCurveLP,
    depositCurveGauge,
    withdrawCurveGauge,
    depositStakeDao,
    withdrawStakeDao,
    depositConvex,
    withdrawConvex,
    depositLlamaLend,
    withdrawLlamaLend,
    transferCurveLP,
    transferCurveGauge,
    transferStakeDaoGauge,
} from "../actions/curveEcoActions";
import {
    pendleDepositPTAndYT,
    pendleDepositLP,
    pendleWithdrawLP,
    pendleWithdrawPT,
    pendleWithdrawYT,
    pendleDepositLPRouter,
    pendleDepositPTRouter,
    pendleDepositYTRouter,
    pendleWithdrawLPRouter,
} from "../actions/pendleActions";
import {borrowUSG, repayUSG, depositAndBorrowUSG, repayUSGAndWithdraw} from "../actions/usgActions";
import {PointsContext} from "../contexts/PointsContext";

export async function executeGeneratedActions(context: PointsContext): Promise<void> {
    try {
        const user1 = context.user1;
        const user2 = context.user2;

        if (!user1 || !user2) {
            throw new Error("Users not initialized. Call initUsers first.");
        }
        await depositCurveLP("USDe_USDC", user1, 1000);

        await depositCurveGauge("USDe_USDC", user1, 100);

        await withdrawCurveGauge("USDe_USDC", user1, 50);

        await transferCurveLP("USDe_USDC", user1, user2, 500);

        await depositCurveLP("USDC_crvUSD", user1, 100);

        await depositStakeDao("USDC_crvUSD", user1, 9000);

        await pendleDepositPTAndYT("fGHO 07/31/25", user1, 200);

        await pendleDepositLP("fGHO 07/31/25", user2, 900);

        await pendleWithdrawYT("fGHO 07/31/25", user1, 50);

        await pendleWithdrawPT("fGHO 07/31/25", user1, 50);

        await context.advanceTime(30);

        await depositLlamaLend("LLAMALEND_sDOLA_crvUSD", user2, 1000);

        await context.advanceTime(30);

        await withdrawStakeDao("USDC_crvUSD", user1, 2000);

        await withdrawCurveLP("USDe_USDC", user1, 20);

        await depositAndBorrowUSG("Market crvUSD-USDC", user2, 5000, 4000);

        await repayUSG("Market crvUSD-USDC", user2, user2, 500);

        await borrowUSG("Market crvUSD-USDC", user2, 500);

        await repayUSGAndWithdraw("Market crvUSD-USDC", user2, 5000, 4000);
    } catch (error) {
        throw error;
    }
}
