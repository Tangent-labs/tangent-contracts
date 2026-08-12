import { ethers } from "hardhat"
import { PROD_ADDRESSES } from "../../../../ignition/prod_addresses"
import { parseEther } from "ethers"

export async function deployTan() {
    const tan = await ethers.deployContract("TAN", [PROD_ADDRESSES.DAO])
    const vsTAN = await ethers.deployContract("VsTAN", [PROD_ADDRESSES.DAO, PROD_ADDRESSES.CONTROL_TOWER, tan, PROD_ADDRESSES.USG, PROD_ADDRESSES.sUSG, PROD_ADDRESSES.ZAPPING_PROXY, parseEther("1000")])

    console.log("TAN", await tan.getAddress())
    console.log("vsTAN", await vsTAN.getAddress())

}

deployTan()