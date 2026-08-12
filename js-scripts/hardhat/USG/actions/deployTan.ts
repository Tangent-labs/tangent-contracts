import { ethers } from "hardhat"
import { PROD_ADDRESSES } from "../../../../ignition/prod_addresses"
import { parseEther } from "ethers"
import { impersonateAccount } from "@nomicfoundation/hardhat-toolbox/network-helpers"

export async function deployTan() {
    const tan = await ethers.deployContract("TAN", [PROD_ADDRESSES.DAO])
    const vsTAN = await ethers.deployContract("VsTAN", [PROD_ADDRESSES.DAO, PROD_ADDRESSES.CONTROL_TOWER, tan, PROD_ADDRESSES.USG, PROD_ADDRESSES.sUSG, PROD_ADDRESSES.ZAPPING_PROXY, parseEther("1000")])

    console.log("TAN", await tan.getAddress())
    console.log("vsTAN", await vsTAN.getAddress())
    const signers = await ethers.getSigners()
    const dao = await ethers.getSigner(PROD_ADDRESSES.DAO)

    const tx = await signers[1].sendTransaction({
        to: dao,
        value: ethers.parseEther("1"),
    });
    await impersonateAccount(PROD_ADDRESSES.DAO)

    for (let index = 0; index < signers.length; index++) {
        const signer = signers[index];
        await tan.connect(dao).transfer(signer, parseEther("10000"))
    }

}

deployTan()