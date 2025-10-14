
import { ethers } from "hardhat";
import { giveTokensToAddresses } from "../../thief/thief";
import { timeTravel } from "../actions/time-travel";
import { depositCurveLP, withdrawCurveLP, depositCurveGauge, withdrawCurveGauge, depositStakeDao, withdrawStakeDao, depositConvex, withdrawConvex, depositLlamaLend, withdrawLlamaLend, transferCurveLP, transferCurveGauge, transferStakeDaoGauge } from '../actions/curveEcoActions';
import { pendleDepositPTAndYT, pendleDepositLP, pendleWithdrawLP, pendleWithdrawPT, pendleWithdrawYT, pendleDepositLPRouter, pendleDepositPTRouter, pendleDepositYTRouter, pendleWithdrawLPRouter } from "../actions/pendleActions";
import { borrowUSG, repayUSG, depositAndBorrowUSG, repayUSGAndWithdraw } from "../actions/usgActions";
import { voteOnGauge } from "../actions/vote-on-gauge";

main();
export async function main() {

    const FXN = "FXN";
    const CRV = "CRV";
    try {
        const [user0, user1, user2, user3, user4, user5, user6, user7, user8, user9] = await ethers.getSigners();
        const lock = await ethers.getContractAt("IVeToken", "0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2")

        await voteOnGauge("STABILITY_POOL", user1, 2, FXN);

        await voteOnGauge("USDC_USDf", user1, 50, CRV);

    } catch (error) {
        throw error;
    }
}