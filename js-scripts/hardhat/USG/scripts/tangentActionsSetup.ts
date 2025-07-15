import {ethers} from "hardhat";
import {giveTokensToAddresses} from "../../thief";
import {TOKENS_TO_GIVE} from "../../tokensToGive.config";
import {depositAndBorrowUSG} from "../actions/depositAndBorrowUSG";
import {instanciateMarket} from "../actions/instanciateMarket";
import {repayUSG} from "../actions/repayUSG";
import {repayUSGAndWithdraw} from "../actions/repayUSGAndWithdraw";

async function main() {
    //
    const user = (await ethers.getSigners())[0];
    await giveTokensToAddresses([user], TOKENS_TO_GIVE(1000000));
    //

    const mkt = await instanciateMarket("0x963B59A52647777E3646034213d6A7B5aEA4F1d8");

    await depositAndBorrowUSG(mkt, "0x963B59A52647777E3646034213d6A7B5aEA4F1d8", user, 10n ** 23n, 10n ** 21n * 4n);

    await repayUSG(mkt, user, 10n ** 18n);

    await repayUSGAndWithdraw(mkt, user, 10n ** 19n, 10n ** 19n);
}

main();
