import { getQuoteZap } from "../odos/getQuoteZap.js";
import { getAssembleData } from "../odos/getAssembleData.js";
import * as ethers from "ethers";

const args = process.argv;

const amountIn = args[2];
const tokenIn = args[3];
const tokenOut = args[4];
const userAddr = args[5];

async function printQuoteOut() {
  const pathId = await getQuoteZap(tokenIn, amountIn, tokenOut, userAddr);

  console.log(
    ethers.parseEther(
      (
        await getQuoteZap(tokenIn, amountIn, tokenOut, userAddr)
      ).outValues[0].toString()
    )
  );
}
printQuoteOut();
