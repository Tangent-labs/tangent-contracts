import {computeIR} from "../../ir/computeIR.mjs";
const args = process.argv;

let tgUSDPrice = args[2];
let isHEC = args[3];
const rMin = args[4];
const rMax = args[5];
const pMin = args[6];
const pInf = args[7];
const pMax = args[8];
const a1 = args[9];
const a2 = args[10];
const k = args[11];

async function printIR() {
    console.log(computeIR(tgUSDPrice, isHEC, rMin, rMax, pMin, pInf, pMax, a1, a2, k));
}
printIR();
