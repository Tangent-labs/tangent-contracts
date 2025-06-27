import {ethers} from "hardhat";
import {pendleDeposit} from "../actions/pendleDeposit";

const marketV2 = "0xd16CB4138A0f09885DefdBc1Fe4a65a8F2fb3950"; // (PT-sDAI)
const marketV3 = "0xb4460e76d99ecad95030204d3c25fb33c4833997"; // (PT-USDe)

const main = async () => {
    const user = (await ethers.getSigners())[0];
    await pendleDeposit(marketV3, ethers.parseEther("1000000000000000000"), ethers.parseEther("1000000000000000000"), user);
};

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
