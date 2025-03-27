import {run} from "hardhat";
import * as addresses from "../../../addresses.json";

const owner = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
const feeTreasury = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
const l0EndpointAddress = "0x1a44076050125825900e736c501f859c50fE728c";
const l0Delegate = "0x1a44076050125825900e736c501f859c50fE728c";
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
        address: addresses.tokens.tgUSD,
        constructorArguments: ["Tangent USD", "tgUSD", l0EndpointAddress, l0Delegate, owner, addresses.utilities.controlTower],
    });

    // SgUSD
    await run("verify:verify", {
        address: addresses.tokens.sgUSD,
        constructorArguments: [],
    });

    // Tan
    await run("verify:verify", {
        address: addresses.tokens.tan,
        constructorArguments: [],
    });

    // RsTan
    await run("verify:verify", {
        address: addresses.tokens.rsTan,
        constructorArguments: [addresses.utilities.controlTower, addresses.tokens.tan],
    });

    // Markets
    for (const [_, marketData] of Object.entries(addresses.markets)) {
        await run("verify:verify", {
            address: marketData.marketAddress,
            constructorArguments: [],
        });
    }

    // Deployed tgUSD LP
    for (const [_, lpAddress] of Object.entries(addresses.lps)) {
        await run("verify:verify", {
            address: lpAddress,
            constructorArguments: [],
        });
    }
}
main();
