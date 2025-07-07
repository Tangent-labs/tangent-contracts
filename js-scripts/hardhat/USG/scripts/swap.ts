import {swapDefault} from "../actions/swapCurve";
import dotenv from "dotenv";

dotenv.config();

async function main() {
    await swapDefault();
}
main();
