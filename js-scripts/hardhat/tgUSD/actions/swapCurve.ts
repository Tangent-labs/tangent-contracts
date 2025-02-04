import {formatUnits, MaxUint256} from "ethers";
import {ethers} from "hardhat";
import {MainSetup} from "../../Main.setup";

// Updated swap function to accept parameters
export async function swap(mainSetup: MainSetup, lpAddress: string, i: number, j: number, amountIn: string) {
    const lp = await ethers.getContractAt("ICurveStableSwapNG", lpAddress);

    const tokenIn = await ethers.getContractAt("ERC20", await lp.coins(i));
    const tokenOut = await ethers.getContractAt("ERC20", await lp.coins(j));

    const tokenInDecimals = await tokenIn.decimals();
    const tokenOutDecimals = await tokenOut.decimals();

    const tokenInName = await tokenIn.name();
    const tokenOutName = await tokenOut.name();

    let balance = await tokenOut.balanceOf(mainSetup.users[0].address);

    await tokenIn.approve(lp, MaxUint256);

    await lp["exchange(int128,int128,uint256,uint256)"](i, j, BigInt(amountIn) * 10n ** tokenInDecimals, 0);

    balance = (await tokenOut.balanceOf(mainSetup.users[0].address)) - balance;

    console.info("\x1b[32m%s\x1b[0m", "Swapped " + amountIn + " " + tokenInName + " and received " + formatUnits(balance, tokenOutDecimals) + " " + tokenOutName + "!");
}

// Example usage of the swap function
export async function swapDefault() {
    const mainSetup = new MainSetup(5);
    await mainSetup.setupTestUsers();

    const lpAddress = process.env.LP_ADDRESS; 
    const i = process.env.INPUT_TOKEN_INDEX; 
    const j = process.env.OUTPUT_TOKEN_INDEX; 
    const amountIn = process.env.AMOUNT_IN; 
    if (!lpAddress || !amountIn || i === undefined || j === undefined) throw Error("Missing env variables for swapDefault");

    await swap(mainSetup, lpAddress, Number(i), Number(j), amountIn);
}

// Call the main function to execute the swap
