import {getQuoteZap} from "../odos/getQuoteZap.mjs";
import {getAssembleData} from "../odos/getAssembleData.mjs";

const args = process.argv;

const amountIn = args[2];
const tokenIn = args[3];
const proportionOut = args[4];
const tokenOut = args[5];
const userAddr = args[6];
const receiver = args[7];

async function printAssembledData() {
    const pathId = (await getQuoteZap(tokenIn, amountIn, tokenOut, userAddr)).pathId;
    const tData = await getAssembleData(pathId, userAddr, receiver);
    console.log(tData.transaction.data);
}
printAssembledData();
