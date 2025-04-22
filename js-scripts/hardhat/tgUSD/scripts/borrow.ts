import {borrowAll} from "../actions/borrow";
import addresses from "../../../../../addresses.json";

async function main() {
    await borrowAll(addresses.markets);
}
main();
