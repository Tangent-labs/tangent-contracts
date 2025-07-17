import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {MaxUint256, parseEther} from "ethers";
import * as usgAddresses from "../../../../addresses.json";

async function getMarketByKey(marketKey: string) {
    const key = marketKey.split("Market ");
    const market = usgAddresses.markets.find((market) => market.collatName === key[1]);

    if (market) {
        return await ethers.getContractAt("MarketExternalActions", market.marketAddress);
    } else {
        throw Error("Incorrect Market key");
    }
}

export const borrowUSG = async (marketKey: string, user: HardhatEthersSigner, borrowAmount: number) => {
    const market = await getMarketByKey(marketKey);
    await market.connect(user).borrow(user, parseEther(borrowAmount.toString()));
};

export const repayUSG = async (marketKey: string, user: HardhatEthersSigner, to: HardhatEthersSigner, repayAmount: number) => {
    const market = await getMarketByKey(marketKey);
    await market.connect(user).repay(to, parseEther(repayAmount.toString()));
};

export const repayUSGAndWithdraw = async (marketKey: string, user: HardhatEthersSigner, withdrawAmount: number, repayAmount: number) => {
    const market = await getMarketByKey(marketKey);
    await market.connect(user).repayAndWithdraw(parseEther(withdrawAmount.toString()), parseEther(repayAmount.toString()));
};

export const depositAndBorrowUSG = async (marketKey: string, user: HardhatEthersSigner, depositAmount: number, borrowAmount: number) => {
    const market = await getMarketByKey(marketKey);
    const collatContract = await ethers.getContractAt("IERC20", await market.collatToken());
    await collatContract.connect(user).approve(market, MaxUint256);
    await market.connect(user).depositAndBorrow(parseEther(depositAmount.toString()), parseEther(borrowAmount.toString()));
};
