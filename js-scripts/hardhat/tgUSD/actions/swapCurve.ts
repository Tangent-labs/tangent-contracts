import { formatUnits, MaxUint256, Signer } from "ethers";
import { ethers } from "hardhat";
import { MainSetup } from "../../Main.setup";

// Updated swap function to accept parameters
export async function swap(user: Signer, lpAddress: string, i: number, j: number, amountIn: string) {

    const lp = await ethers.getContractAt("ICurveStableSwapNG", lpAddress);
    const userAddress = await user.getAddress()

    const tokenIn = await ethers.getContractAt("ERC20", await lp.coins(i));
    const tokenOut = await ethers.getContractAt("ERC20", await lp.coins(j));

    const tokenInDecimals = await tokenIn.decimals();
    const tokenOutDecimals = await tokenOut.decimals();
    const tokenInName = await tokenIn.name();
    const tokenOutName = await tokenOut.name();

    const amountRawIn = BigInt(amountIn) * 10n ** tokenInDecimals

    // const balancePoolIn= await tokenIn.balanceOf(lpAddress)
    // const balancePoolOut = await tokenOut.balanceOf(lpAddress)
    // console.log({balancePoolIn:formatUnits(balancePoolIn,tokenInDecimals),balancePoolOut:formatUnits(balancePoolOut,tokenOutDecimals) })

    let balanceIn = await tokenIn.balanceOf(userAddress);
    if (balanceIn < amountRawIn) {
        console.info("\x1b[38;5;208m%s\x1b[0m", `Not enough balance  ${formatUnits(balanceIn, tokenInDecimals)} / ${amountIn} ${tokenInName} ` );
        return ;
    }

    let balance = await tokenOut.balanceOf(userAddress);
    try {
        await tokenIn.approve(lp, MaxUint256);
        await lp["exchange(int128,int128,uint256,uint256)"](i, j, amountRawIn, 0);
        balance = (await tokenOut.balanceOf(await userAddress)) - balance;
        console.info("\x1b[32m%s\x1b[0m", "Swapped " + amountIn + " " + tokenInName + " and received " + formatUnits(balance, tokenOutDecimals) + " " + tokenOutName + "!");
      
    } catch (e) {
        console.info("\x1b[38;5;208m%s\x1b[0m", "Error Swap : " + tokenInName + "/ " + tokenOutName, (e as Error).message);
        //console.log(e);
    }
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

    await swap(mainSetup.users[0], lpAddress, Number(i), Number(j), amountIn);
}

// Call the main function to execute the swap
