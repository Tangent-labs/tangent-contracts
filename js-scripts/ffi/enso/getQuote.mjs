import {getQuote} from "../../enso/getQuote.mjs";
import * as ethers from "ethers";

const args = process.argv;

const tokenIn = args[2];
const amountIn = args[3];
const tokenOut = args[4];

async function printQuoteOut() {
    const quote = await getQuote(tokenIn, amountIn, tokenOut);
    console.log(BigInt(quote.amountOut));
}
printQuoteOut();
