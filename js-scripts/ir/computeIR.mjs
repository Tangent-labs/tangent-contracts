import * as ethers from "ethers";

export function computeIR(tgUSDPrice, isHEC, rMin, rMax, pMin, pInf, pMax, a1, a2, k) {
    const tgUSDPriceNumber = Number(ethers.formatEther(BigInt(tgUSDPrice)));
    const nomalizedPMin = Number(ethers.formatUnits(pMin, 6));
    const nomalizedPMax = Number(ethers.formatUnits(pMax, 6));
    if (tgUSDPriceNumber <= nomalizedPMin) {
        return ethers.parseUnits(rMax, 13);
    }
    if (tgUSDPriceNumber >= nomalizedPMax) {
        if (isHEC === "true") {
            return "0";
        }
        return ethers.parseUnits(rMin, 13);
    }
    const priceDelta = tgUSDPriceNumber - Number(ethers.formatUnits(pInf, 6));

    const sigmaX = Number(k) * priceDelta;

    const exp = Math.exp(-sigmaX);

    const sigma = 1 / (1 + exp);

    const alpha1 = Number(a1) / 1_000;
    const alpha = alpha1 + (Number(a2) / 1_000 - alpha1) * sigma;

    const quotient = (nomalizedPMax - tgUSDPriceNumber) / (nomalizedPMax - nomalizedPMin);

    const priceRatio = quotient ** alpha;

    const irIncrement = Number(ethers.formatUnits(rMax - rMin, 5)) * priceRatio;

    // console.log("sigma", sigma);
    // console.log("alpha", alpha);
    // console.log("quotient", quotient);
    // console.log("priceRatio", priceRatio);
    // console.log("irIncrement", irIncrement);

    const ir = Number(ethers.formatUnits(rMin, 5)) + irIncrement;

    return ethers.parseEther(ir.toFixed(18));
}
