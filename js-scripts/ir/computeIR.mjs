import * as ethers from "ethers";

export function computeIR(tgUSDPrice, rMin, rMax, pMin, pInf, pMax, a1, a2, k) {
    // console.log(tgUSDPrice);
    const tgUSDPriceNumber = Number(ethers.formatEther(BigInt(tgUSDPrice)));
    const nomalizedPMin = Number(ethers.formatUnits(pMin, 6));
    const nomalizedPMax = Number(ethers.formatUnits(pMax, 6));

    // console.log(tgUSDPriceNumber, nomalizedPMin, nomalizedPMax);

    // console.log(tgUSDPriceNumber, nomalizedPMin, nomalizedPMax);
    if (tgUSDPriceNumber < nomalizedPMin) {
        return ethers.parseUnits(rMax, 13);
    }
    if (tgUSDPriceNumber > nomalizedPMax) {
        return ethers.parseUnits(rMin, 13);
    }

    const priceDelta = tgUSDPriceNumber - Number(ethers.formatUnits(pInf, 6));
    // console.log("priceDelta", priceDelta);

    const gammaX = Number(k) * priceDelta;

    // console.log("gammaX", gammaX);

    const exp = Math.exp(-gammaX);
    // console.log("exp", exp);

    const gamma = 1 / (1 + exp);
    // console.log("gamma", gamma);
    const alpha = Number(a1) + (Number(a2) - Number(a1)) * gamma;

    // console.log("alpha", alpha);

    const quotient = (nomalizedPMax - tgUSDPriceNumber) / (nomalizedPMax - nomalizedPMin);

    const priceRatio = quotient ** alpha;

    // console.log("priceRatio", priceRatio);

    const irIncrement = Number(ethers.formatUnits(rMax - rMin, 5)) * priceRatio;

    // console.log("irMin", Number(ethers.formatUnits(rMin, 5)));
    // console.log("irIncrement", irIncrement);

    // console.log(irIncrement);

    const ir = Number(ethers.formatUnits(rMin, 5)) + irIncrement;

    // console.log(ir);

    // let stringIr = ir.toString();

    // if (stringIr.length > 18) {
    //     stringIr = stringIr.slice(0, 18 - stringIr.length);
    // }

    return ethers.parseEther(ir.toFixed(18));
}
// console.log(computeIR("1120000000000003178", "19055", "902629", "11933", "1998267", "1990595", "13199", "6100", "56165"));
