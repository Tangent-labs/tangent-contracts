import {depositAll} from "../actions/deposit";
import addresses from "../../../../../addresses.json";

async function main() {
    await depositAll(addresses.markets);
}
main();
