import {ethers} from "hardhat";

export const instanciateMarket = async (marketAddress: string) => {
    return await ethers.getContractAt("MarketExternalActions", marketAddress);
};
