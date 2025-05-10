import {createJSONAddress} from "../contexts/BaseContext";

import * as fs from "fs";

import {deploytgUsd} from "../actions/deploytgUsd";

async function main() {
    const {baseContext, marketContext, oracleContext, lpDeployContext, wStableContext} = await deploytgUsd();

    fs.writeFileSync("./addresses.json", JSON.stringify(await createJSONAddress(baseContext, marketContext, oracleContext, lpDeployContext, wStableContext)));
    console.info("\x1b[32m%s\x1b[0m", "Contracts deployed and setup !");
}

main();
