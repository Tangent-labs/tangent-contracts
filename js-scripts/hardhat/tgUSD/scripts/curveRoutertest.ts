import { ethers } from "hardhat";
import { } from "hardhat-tracer"
import addresses from "../../../../addresses-liquidation.json";
import { thiefConfig } from "defi-resources";
import { AddressLike, parseEther, ZeroAddress } from "ethers";


const curveRouterAddress = "0x16C6521Dff6baB339122a0FE25a9116693265353";
const USDC = thiefConfig.THIEF_TOKEN_CONFIG.USDC;

async function main() {

    const marketData = addresses.markets.find(m => m.collatName === "USDC_fxUSD");
    if (!marketData)
        throw new Error("Market not found");

    const user = (await ethers.getSigners()).at(0);
    if (!user) throw new Error("User not found");
    const userAddress = await user.getAddress()

    const deployed = {
        usdcTgUSd: addresses.lps["tgUSD-USDC"],
        tgUSD: addresses.tokens.tgUSD
    }

    const contracts = {
        curveRouter: await ethers.getContractAt("ICurveRouter", curveRouterAddress),
        tgUsd: await ethers.getContractAt("IERC20Metadata", deployed.tgUSD),
        collat: await ethers.getContractAt("IERC20Metadata", marketData.collatAddress),
        usdcTgUSd: await ethers.getContractAt("IERC20Metadata", deployed.usdcTgUSd)

    }

    // console.log('usdcTgUSd' , await contracts.usdcTgUSd.symbol());
    // console.log('tgUsd', await contracts.tgUsd.symbol());
    // console.log('collat', await contracts.collat.symbol());

    // get the route and swap params
    const { routes, swapParams, zapPools } = routeParams(marketData, deployed.usdcTgUSd, deployed.tgUSD);
    const amount = parseEther("100");

    const balanceBefore = await contracts.tgUsd.balanceOf(userAddress);
    const balanceLpBefore = await contracts.collat.balanceOf(userAddress);
    console.log('balance check ', { balanceLpBefore, rest: balanceLpBefore - amount });
    let amountOut: bigint | undefined
    try {
        // @ts-ignore
        amountOut = await contracts.curveRouter.connect(user).get_dy(routes!, swapParams!, amount!, zapPools!);
        console.log('dy', { amountOut });
    } catch (e) {
        console.error(' ------> get_dy error');
    }

    await contracts.collat.connect(user).approve(curveRouterAddress, amount * 2n);
    try {

        // @ts-ignore
        await contracts.curveRouter.connect(user).exchange(routes!, swapParams!, amount, 0, zapPools, userAddress);
    } catch (e) {
        console.error('------> exchange error', e.message);
    }

    const balanceAfter = await contracts.tgUsd.balanceOf(userAddress);
    console.log(balanceBefore, balanceAfter);




    //  pour liquider 
    // exemple : test\tgUSD\unit\Liquidation\SecondaryLiquidation\SecondaryLiqdtCurveLp.t.sol ligne 71

}

const routeParams = (marketData: { collatAddress: AddressLike }, usdcTgUSd: AddressLike, tgUSD: AddressLike) => {

    // https://docs.curve.fi/router/CurveRouterNG/#_route

    const routes: AddressLike[] = new Array(11).fill(ZeroAddress);
    {
        let i = 0
        routes[i++] = marketData.collatAddress; // LP collat  => token 
        routes[i++] = marketData.collatAddress; // **SWAP**  LP collat  => USDC (remove liquidity) 
        routes[i++] = USDC.address; // USDC 
        routes[i++] = usdcTgUSd; //**SWAP** USDC >  tgUSD  POOL tgUSD-USDC    
        routes[i++] = tgUSD; // tgUSD
    }

    const swapParams: number[][] = new Array(5).fill(new Array(5).fill(0));
    {
        let i = 0;
        swapParams[i++] = [0, 0, 6, 1, 2];  // **SWAP**  LP collat  => USDC (remove liquidity) 
        swapParams[i++] = [0, 1, 1, 10, 2]; // **SWAP** USDC >  tgUSD  POOL tgUSD-USDC    
    }

    const zapPools: AddressLike[] = new Array(5).fill(ZeroAddress);

    //  console.log({ routes, swapParams, zapPools });
    return { routes, swapParams, zapPools }
}


const routeParamsDola = () => {
    const pool = '0xaa5a67c256e27a5d80712c51971408db3370927d' // DOLA-3pool Curve LP
    // type : Stableswap, Metapool
}






export type RouteParams = {
    collateral: string,
    name: string
    collateralOut: string,
    wTOkenPool?: string, // Leave empty for none wTOken route
    routes: {
        pool1: string,
        token1: string,
        pool2: string,
        token2: string,
        pool3: string,
        token3: string,
    }
    swapParams: number[][],
    zapPools: AddressLike[]
}




main();