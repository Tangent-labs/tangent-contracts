import {ethers} from "hardhat";

export async function manipulateOracle(marketAddress: string, amount: number) {
    const marketContract = await ethers.getContractAt("Collateral", marketAddress);
    const oracle = await marketContract.collatOracle();
    const oracleContract = await ethers.getContractAt("MockOracle", oracle);
    await oracleContract.setLastAnswer(amount);
}
