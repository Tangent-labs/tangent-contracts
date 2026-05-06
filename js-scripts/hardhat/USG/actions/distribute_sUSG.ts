import { impersonateAccount, stopImpersonatingAccount } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { parseEther } from "ethers";
import { ethers } from "hardhat";
import { PROD_ADDRESSES } from "../../../../ignition/prod_addresses";

export async function distributeSUSG() {
    const sUSG = await ethers.getContractAt("IYearnV3Vault", PROD_ADDRESSES.sUSG);
    const USG = await ethers.getContractAt("ERC20", PROD_ADDRESSES.USG);
    const testUserWithUSG = (await ethers.getSigners())[3]
    const testUser = await testUserWithUSG.getAddress()
    const dao = await ethers.getSigner(PROD_ADDRESSES.DAO)

    // await sUSG.connect(dao).set_role(PROD_ADDRESSES.DAO, 32)

    await impersonateAccount(testUser)
    await USG.connect(testUserWithUSG).transfer(sUSG, parseEther("2000"))
    await stopImpersonatingAccount(testUser)

    await impersonateAccount(PROD_ADDRESSES.DAO)

    await sUSG.connect(dao).process_report(sUSG)
    await impersonateAccount(PROD_ADDRESSES.DAO)

    console.info("\x1b[32m%s\x1b[0m", "sUSG distributed with sucess");
}

export async function switchOwner() {
    const irCalculator = await ethers.getContractAt("IRCalculator", PROD_ADDRESSES.REWARDS_ACCUMULATOR);
    const newOwner = (await ethers.getSigners())[0]
    const dao = await ethers.getSigner(PROD_ADDRESSES.DAO)


    await impersonateAccount(PROD_ADDRESSES.DAO)
    await irCalculator.connect(dao).transferOwnership(newOwner)
    await stopImpersonatingAccount(PROD_ADDRESSES.DAO)

    console.info("\x1b[32m%s\x1b[0m", "Owner changed");
}

distributeSUSG();
