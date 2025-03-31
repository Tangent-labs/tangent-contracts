import {Client} from "pg";
import * as addresses from "../../../../addresses.json";
import * as wStableAbi from "../../../../artifacts/src/tgUSD/tokens/WStable.sol/WStable.json";
import * as curveStableSwapNG from "../../../../artifacts/src/interfaces/externals/Curve/ICurveStableSwapNG.sol/ICurveStableSwapNG.json";
import {curveLp} from "defi-resources";
import {forceAbi} from "./insertContractInDb";

export async function verifyContracts() {
    const client = new Client({
        user: "blockscout",
        host: "176.143.254.58",
        database: "blockscout",
        password: "ceWb1MeLBEeOIfk65gU8EjF8",
        port: 7432, // Par défaut PostgreSQL utilise 5432
    });
    await client.connect();

    // Curve LP

    await forceAbi(client, curveLp.crvUSD_USDC, "crvUSD/USDC", true, curveStableSwapNG.abi);
    await forceAbi(client, curveLp.crvUSD_USDT, "crvUSD/USDT", true, curveStableSwapNG.abi);

    // tgUSD Lps
    for (const [name, address] of Object.entries(addresses.lps)) {
        await forceAbi(client, address, name, true, curveStableSwapNG.abi);
    }

    // WStables
    for (const [name, address] of Object.entries(addresses.wStables)) {
        await forceAbi(client, address, name, true, wStableAbi.abi);
    }

    await client.end();
}
verifyContracts();
