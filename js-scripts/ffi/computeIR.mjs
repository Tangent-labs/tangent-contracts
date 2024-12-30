import * as ethers from "ethers";
const args = process.argv;

const tgUSDPrice = args[2];
const irStartPrice = args[3];
const sigma = args[4];
const r0 = args[5];

async function printIR() {
    if (BigInt(tgUSDPrice) > BigInt(irStartPrice)) {
        console.log(0n);
        return;
    }
    const deltaTo1 = 1 - Number(ethers.formatEther(tgUSDPrice));
    const exp = Math.exp(deltaTo1 / Number(ethers.formatEther(sigma)));
    const ir = exp * Number(ethers.formatEther(r0));
    console.log(ethers.parseEther(ir.toString()));
}
printIR();
