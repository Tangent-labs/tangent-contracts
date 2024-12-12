import * as ethers from "ethers";
const args = process.argv;

const tgUSDPrice = args[2];
const sigma = args[3];
const r0 = args[4];

async function printIR() {
    const deltaTo1 = 1 - Number(ethers.formatEther(tgUSDPrice));
    const exp = Math.exp(deltaTo1 / Number(ethers.formatEther(sigma)));
    const ir = exp * Number(ethers.formatEther(r0));
    console.log(ethers.parseEther(ir.toString()));
}
printIR();
