import {ethers} from "hardhat";
import {giveTokensToAddresses} from "../../thief";
import {timeTravel} from "../actions/time-travel";
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
import {TOKENS_TO_GIVE} from "../../tokensToGive.config";

main();
export async function main() {
    try {
        const [user0, user1, user2, user3, user4, user5, user6, user7, user8, user9] = await ethers.getSigners();
        await giveTokensToAddresses([user0, user1, user2, user3, user4, user5, user6, user7, user8, user9], TOKENS_TO_GIVE(100000000));

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

        await timeTravel(30);

        await depositLlamaLend("LLAMALEND_sDOLA_crvUSD", user2, 1000);

        await timeTravel(30);

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
