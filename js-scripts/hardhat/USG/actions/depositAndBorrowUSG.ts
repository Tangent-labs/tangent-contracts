import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {MarketExternalActions} from "../../../../typechain-types";
import {MaxUint256} from "ethers";
import {ethers} from "hardhat";
import {instanciateMarket} from "./instanciateMarket";

export const depositAndBorrowUSG = async (market: MarketExternalActions, marketAddress: string, user: HardhatEthersSigner, depositAmount: bigint, borrowAmount: bigint) => {
    const mkt = await instanciateMarket(marketAddress);
    const collatAddress = await mkt.collatToken();
    const collatContract = await ethers.getContractAt("IERC20", collatAddress);
    await collatContract.connect(user).approve(marketAddress, MaxUint256);
    await market?.connect(user)?.depositAndBorrow(depositAmount, borrowAmount);
};
