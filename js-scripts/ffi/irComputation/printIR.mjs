import {formatEther, parseEther, formatUnits, parseUnits} from "ethers";
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

printIR();

function printIR() {
    console.log(computeIR(tgUSDPrice, isHEC, rMin, rMax, pMin, pInf, pMax, a1, a2, k));
}

function computeIR(tgUSDPrice, isHEC, rMin, rMax, pMin, pInf, pMax, a1, a2, k) {
    const tgUSDPriceNumber = Number(formatEther(BigInt(tgUSDPrice)));
    const nomalizedPMin = Number(formatUnits(pMin, 6));
    const nomalizedPMax = Number(formatUnits(pMax, 6));
    if (tgUSDPriceNumber <= nomalizedPMin) {
        return parseUnits(rMax, 13);
    }
    if (tgUSDPriceNumber >= nomalizedPMax) {
        if (isHEC === "true") {
            return "0";
        }
        return parseUnits(rMin, 13);
    }
    const priceDelta = tgUSDPriceNumber - Number(formatUnits(pInf, 6));

    const sigmaX = Number(k) * priceDelta;

    const exp = Math.exp(-sigmaX);

    const sigma = 1 / (1 + exp);

    const alpha1 = Number(a1) / 1_000;
    const alpha = alpha1 + (Number(a2) / 1_000 - alpha1) * sigma;

    const quotient = (nomalizedPMax - tgUSDPriceNumber) / (nomalizedPMax - nomalizedPMin);

    const priceRatio = quotient ** alpha;

    const irIncrement = Number(formatUnits(rMax - rMin, 5)) * priceRatio;

    const ir = Number(formatUnits(rMin, 5)) + irIncrement;

    return parseEther(ir.toFixed(18));
}
