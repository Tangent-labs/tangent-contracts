import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {MarketExternalActions} from "../../../../typechain-types";

export const repayUSGAndWithdraw = async (market: MarketExternalActions, user: HardhatEthersSigner, repayAmount: bigint, withdrawAmount: bigint) => {
    await market.connect(user).repayAndWithdraw(withdrawAmount, repayAmount);
};
