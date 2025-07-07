import {createJSONAddress} from "../contexts/BaseContext";

import * as fs from "fs";

import {deployUSG} from "../actions/deployUSG";

async function main() {
    const {baseContext, marketContext, oracleContext, lpDeployContext, wStableContext} = await deployUSG();

    fs.writeFileSync("./addresses.json", JSON.stringify(await createJSONAddress(baseContext, marketContext, oracleContext, lpDeployContext, wStableContext)));
    console.info("\x1b[32m%s\x1b[0m", "Contracts deployed and setup !");
}

main();
