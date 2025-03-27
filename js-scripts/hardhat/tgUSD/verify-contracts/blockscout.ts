import * as fs from "fs";
import * as addresses from "addresses.json";

async function verifyContract(address: string, name: string) {
    let flattened = fs.readFileSync(`flattened/${name}_flat.sol`);
    const response = await fetch(`http://176.143.254.58/api/v2/smart-contracts/${address}/verification/via/flattened-code`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            compiler_version: "v0.8.28+commit.7893614a",
            license_type: 3,
            source_code: flattened.toString(),
            contract_name: name,
            // autodetect_constructor_args: true,
        }),
    });
    const data = await response.json();
    console.log(response);
}

async function main() {
    await verifyContract(addresses.utilities.controlTower, "ControlTower");

    // // Control Tower
    // await run("verify:verify", {
    //     address: addresses.utilities.controlTower,
    //     constructorArguments: [owner, feeTreasury],
    // });
    // // Reward Accumulator
    // await run("verify:verify", {
    //     address: addresses.utilities.rewardAccumulator,
    //     constructorArguments: [owner, addresses.utilities.controlTower],
    // });
    // // Zapper
    // await run("verify:verify", {
    //     address: addresses.utilities.zapper,
    //     constructorArguments: [owner, addresses.utilities.controlTower, addresses.tokens.tgUSD],
    // });
    // // // Market Creator
    // // await run("verify:verify", {
    // //     address: addresses.utilities.marketCreator,
    // //     constructorArguments: ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "0xB1fC11F03b084FfF8daE95fA08e8D69ad2547Ec1"],
    // // });
    // // TgUSD
    // await run("verify:verify", {
    //     address: addresses.tokens.tgUSD,
    //     constructorArguments: ["Tangent USD", "tgUSD", l0EndpointAddress, l0Delegate, owner, addresses.utilities.controlTower],
    // });
    // // SgUSD
    // await run("verify:verify", {
    //     address: addresses.tokens.sgUSD,
    //     constructorArguments: [],
    // });
    // // Tan
    // await run("verify:verify", {
    //     address: addresses.tokens.tan,
    //     constructorArguments: [],
    // });
    // // RsTan
    // await run("verify:verify", {
    //     address: addresses.tokens.rsTan,
    //     constructorArguments: [addresses.utilities.controlTower, addresses.tokens.tan],
    // });
    // // Markets
    // for (const [_, marketData] of Object.entries(addresses.markets)) {
    //     await run("verify:verify", {
    //         address: marketData.marketAddress,
    //         constructorArguments: [],
    //     });
    // }
    // // Deployed tgUSD LP
    // for (const [_, lpAddress] of Object.entries(addresses.lps)) {
    //     await run("verify:verify", {
    //         address: lpAddress,
    //         constructorArguments: [],
    //     });
    // }
}
main();
