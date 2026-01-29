
import { ethers } from "hardhat";
import { giveTokensToAddresses } from "../../thief/thief";
import { timeTravel } from "../actions/time-travel";
import { depositCurveLP, withdrawCurveLP, depositCurveGauge, withdrawCurveGauge, depositStakeDao, withdrawStakeDao, depositConvex, withdrawConvex, depositLlamaLend, withdrawLlamaLend, transferCurveLP, transferCurveGauge, transferStakeDaoGauge, depositCurveLPOneSide } from '../actions/curveEcoActions';
import { pendleDepositPTAndYT, pendleDepositLP, pendleWithdrawLP, pendleWithdrawPT, pendleWithdrawYT, pendleDepositLPRouter, pendleDepositPTRouter, pendleDepositYTRouter, pendleWithdrawLPRouter } from "../actions/pendleActions";
import { borrowUSG, repayUSG, depositAndBorrowUSG, repayUSGAndWithdraw } from "../actions/usgActions";
import { voteOnGauge } from "../actions/vote-on-gauge";

main();
export async function main() {

    const FXN = "FXN";
    const CRV = "CRV";
    try {
        const [user0, user1, user2, user3, user4, user5, user6, user7, user8, user9] = await ethers.getSigners();

        await depositCurveLPOneSide("USDC_crvUSD", user8, 500000);

        // await withdrawCurveLP("USDC_crvUSD", user8, 219058);
    } catch (error) {
        throw error;
    }
}