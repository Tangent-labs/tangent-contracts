import {run} from "hardhat";
import * as addresses from "../../../addresses.json";

const owner = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
const feeTreasury = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
async function main() {
    // Control Tower
    await run("verify:verify", {
        address: addresses.utilities.controlTower,
        constructorArguments: [owner, feeTreasury],
    });

    // Reward Accumulator
    await run("verify:verify", {
        address: addresses.utilities.rewardAccumulator,
        constructorArguments: [owner, addresses.utilities.controlTower],
    });

    // Zapper
    await run("verify:verify", {
        address: addresses.utilities.zapper,
        constructorArguments: [owner, addresses.utilities.controlTower, addresses.tokens.tgUSD],
    });

    // // Market Creator
    // await run("verify:verify", {
    //     address: addresses.utilities.marketCreator,
    //     constructorArguments: ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "0xB1fC11F03b084FfF8daE95fA08e8D69ad2547Ec1"],
    // });

    // TgUSD
    await run("verify:verify", {
        address: "0xFBc00Fa47a7d3bbE3e82B5Aa560B47008c1bD64c",
        constructorArguments: ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "0xB1fC11F03b084FfF8daE95fA08e8D69ad2547Ec1"],
    });
}
main();
