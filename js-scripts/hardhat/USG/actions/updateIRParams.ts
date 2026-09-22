import { impersonateAccount, stopImpersonatingAccount } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { ethers, network } from "hardhat";
import { PROD_ADDRESSES } from "../../../../ignition/prod_addresses";

/**
 * Flat 10% fixed rate.
 *
 * pMin = 0 / pInf = pMax = 1 makes every USG price above 0.000001$ exit `_computeIR`
 * on its `price >= pMax` branch, so the ABDK sigmoid is never evaluated (~21k gas
 * saved on every checkpointIR). rMin == rMax keeps the rate identical on the
 * branches that config leaves unreachable.
 *
 * isHEC MUST stay false: on that same branch a HEC market returns 0 instead of rMin.
 */
const FIXED_RATE_PARAMS = {
    isHEC: false,
    rMin: 10_000, // 10%
    rMax: 10_000, // 10%
    pMin: 0,
    pInf: 1,
    pMax: 1,
    a1: 0,
    a2: 0,
    k: 0,
};

const format = (p: any) =>
    `isHEC=${p.isHEC} rMin=${p.rMin} rMax=${p.rMax} pMin=${p.pMin} pInf=${p.pInf} pMax=${p.pMax} a1=${p.a1} a2=${p.a2} k=${p.k}`;

export async function updateIRParams(marketAddress: string, params = FIXED_RATE_PARAMS) {
    const irCalculator = await ethers.getContractAt("IRCalculator", PROD_ADDRESSES.IR_CALCULATOR);

    const before = await irCalculator.getIRParams(marketAddress);
    console.info(`Market       : ${marketAddress}`);
    console.info(`Current      : ${format(before)}`);
    console.info(`Target       : ${format(params)}`);

    // `updateIRParams` is onlyOwner - on mainnet this has to be executed by the DAO Safe.
    const owner = await irCalculator.owner();
    const calldata = irCalculator.interface.encodeFunctionData("updateIRParams", [marketAddress, params]);
    console.info(`\nSafe tx      : to=${PROD_ADDRESSES.IR_CALCULATOR} owner=${owner}\ndata         : ${calldata}\n`);

    if (network.name !== "localhost" && network.name !== "hardhat") {
        console.info("\x1b[33m%s\x1b[0m", "Not on a fork: calldata printed only, nothing sent.");
        return;
    }

    const [, , funder] = await ethers.getSigners();
    await funder.sendTransaction({ to: owner, value: ethers.parseEther("1.0") });

    await impersonateAccount(owner);
    await irCalculator.connect(await ethers.getSigner(owner)).updateIRParams(marketAddress, params);
    await stopImpersonatingAccount(owner);

    const after = await irCalculator.getIRParams(marketAddress);
    console.info(`Applied      : ${format(after)}`);

    // Sanity check: the rate must now be flat whatever USG is worth.
    for (const price of ["0.97", "0.995", "1.0", "1.02"]) {
        const ir = await irCalculator.simulateIR(ethers.parseEther(price), params);
        console.info(`  USG @ ${price.padEnd(5)}$ -> IR ${ethers.formatEther(ir * 100n)}%`);
    }

    console.info("\x1b[32m%s\x1b[0m", "IRParams updated with success");
}

updateIRParams(PROD_ADDRESSES.MARKETS.STAKEDAO_VAULT.cbBTC_WBTC);
