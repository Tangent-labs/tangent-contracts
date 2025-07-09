import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {MarketExternalActions} from "../../../../typechain-types";

export const repayUSG = async (market: MarketExternalActions, user: HardhatEthersSigner, repayAmount: bigint) => {
    const userAddress = await user.getAddress();
    await market?.connect(user)?.repay(userAddress, repayAmount);
};
