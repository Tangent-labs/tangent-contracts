import { giveTokenToAddress } from "../thief/thief";
import { ethers } from "hardhat";
import { parseEther } from "ethers";
import { cvgCVX } from "@tangent/defi-resources/build/ressources/erc20/convex";

async function main() {
    const users = await ethers.getSigners()

    const cvgCVXContract = await ethers.getContractAt("ICvgCVX", cvgCVX)

    for (let i = 0; i < users.length; i++) {
        const user = users[i];
        await giveTokenToAddress(user, "cvgCVX", parseEther("1000"))
    }

    await cvgCVXContract.connect(users[0]).burn(parseEther("150"))

    await cvgCVXContract.connect(users[1]).burn(parseEther("300"))

    await cvgCVXContract.connect(users[1]).burn(parseEther("500"))



}
main();
