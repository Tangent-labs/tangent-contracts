import {computeIR} from "../../ir/computeIR.mjs";
const args = process.argv;

let tgUSDPrice = args[2];
const rMin = args[3];
const rMax = args[4];
const pMin = args[5];
const pInf = args[6];
const pMax = args[7];
const a1 = args[8];
const a2 = args[9];
const k = args[10];

async function printIR() {
    console.log(computeIR(tgUSDPrice, rMin, rMax, pMin, pInf, pMax, a1, a2, k));
}
printIR();
