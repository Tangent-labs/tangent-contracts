import {depositAll} from "../actions/deposit";
import {loadAddresses} from "../actions/common";

async function main() {
    const addresses = loadAddresses();
    await depositAll(addresses.markets);
}
main();
