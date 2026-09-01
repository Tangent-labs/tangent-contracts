import { giveTokenToAddress } from "../thief/thief";
import { ethers } from "hardhat";
import { parseEther } from "ethers";
import { COMMON_ERC20S } from "@tangent/defi-resources";
import { impersonateAccount } from "@nomicfoundation/hardhat-toolbox/network-helpers";

async function main() {
    // Constants
    const users = await ethers.getSigners()
    const CVX = await ethers.getContractAt("ERC20", COMMON_ERC20S.CVX)
    const cvxMulti = await ethers.getSigner("0x11B6B453019DcdE7F0048348ff954bF29a6D6853");

    // Prepare
    await giveTokenToAddress(cvxMulti, "CVX", parseEther("100000"));

    await users[0].sendTransaction({
        to: cvxMulti,
        value: parseEther("2")
    })

    // Actions

    await impersonateAccount(await cvxMulti.getAddress())

    await CVX.connect(cvxMulti).transfer(users[0], parseEther("150"))
    await CVX.connect(cvxMulti).transfer(users[1], parseEther("300"))
    await CVX.connect(cvxMulti).transfer(users[2], parseEther("12"))

}
main();
