import {formatUnits, MaxUint256} from "ethers";
import {ethers} from "hardhat";
import {MainSetup} from "../../Main.setup";

const lpAddress = process.env.LP!;
const amountIn = process.env.AMOUNT_IN!;
const i = process.env.I!;
const j = process.env.J!;

export async function swap() {
    const mainSetup = new MainSetup();
    await mainSetup.setupTestUsers();
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

    console.info("\x1b[32m%s\x1b[0m", "Swaped " + amountIn + " " + tokenInName + " and received " + formatUnits(balance, tokenOutDecimals) + " " + tokenOutName + " !");
}

swap();
