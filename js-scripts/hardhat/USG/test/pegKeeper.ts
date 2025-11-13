import { ethers } from "hardhat";
import { Signer } from "ethers";
import { swap } from "../actions/swapCurve";
import * as addresses from "../../../../addresses.json"
import { timeTravel } from "../actions/time-travel";

async function keeperTest() {
    const user = (await ethers.getSigners())[0] as unknown as Signer;

    const usg = await ethers.getContractAt("USG", addresses.tokens.USG)
    await usg.mintPegKeeper(addresses.pegKeepers["USG-USDC"], ethers.parseEther("1000000"))
    await usg.mintPegKeeper(addresses.pegKeepers["USG-wcrvUSD"], ethers.parseEther("1000000"))

    await swap(user, addresses.lps["USG-USDC"], 0, 1, "200000")
    await swap(user, addresses.lps["USG-wcrvUSD"], 0, 1, "200000")

    await timeTravel(1)
};


keeperTest()