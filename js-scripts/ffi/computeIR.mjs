import * as ethers from "ethers";
const args = process.argv;

let tgUSDPrice = args[2];
const priceIRMax = args[3];
const irStartPrice = args[4];
const sigma = args[5];
const r0 = args[6];

async function printIR() {
    if (BigInt(tgUSDPrice) > BigInt(irStartPrice)) {
        console.log(0n);
        return;
    }
    if (BigInt(tgUSDPrice) < BigInt(priceIRMax)) {
        tgUSDPrice = priceIRMax;
    }

    const deltaTo1 = 1 - Number(ethers.formatEther(tgUSDPrice));
    const exp = Math.exp(deltaTo1 / Number(ethers.formatEther(sigma)));
    const ir = exp * Number(ethers.formatEther(r0));
    console.log(ethers.parseEther(ir.toString()));
}
printIR();
