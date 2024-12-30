import {getQuote} from "../../enso/getQuote.mjs";
import {getRoute} from "../../enso/getRoute.mjs";

const args = process.argv;

const fromAddress = args[2];
const receiver = args[3];
const tokenIn = args[4];
const amountIn = args[5];
const tokenOut = args[6];
const minAmountOut = args[7];

async function printRouteData() {
    const tData = await getRoute(fromAddress, receiver, tokenIn, amountIn, tokenOut, minAmountOut);
    console.log(tData.tx.data);
}
printRouteData();
