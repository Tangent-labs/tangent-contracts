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

    const mkt = await instanciateMarket("0x91Eb504dc608b66619067A808323DE79f4096036");

    await depositAndBorrowUSG(mkt, "0x91Eb504dc608b66619067A808323DE79f4096036", user, 10n ** 22n, 10n ** 22n * 3n);

    await repayUSG(mkt, user, 10n ** 18n);

    await repayUSGAndWithdraw(mkt, user, 10n ** 19n, 10n ** 19n);
}

main();
