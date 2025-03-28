import {ethers} from "hardhat";
import {} from "hardhat-tracer";
import addresses from "../../../../addresses-liquidation.json";
import {thiefConfig} from "defi-resources";
import {AddressLike, parseEther, ZeroAddress} from "ethers";
import { giveTokensoAddresss } from "../../thief";

const curveRouterAddress = "0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e";
const USDC = thiefConfig.THIEF_TOKEN_CONFIG.USDC;

async function main() {
    const marketData = addresses.markets.find((m) => m.collatName === "USDC_fxUSD");
    if (!marketData) throw new Error("Market not found");

    const user = (await ethers.getSigners()).at(0);
    if (!user) throw new Error("User not found");
    const userAddress = await user.getAddress();

    const inData = {
        isVyper: false,
        slot: 6,
        address: '0x865377367054516e17014CcdED1e7d814EDC9ce4',
        decimals: 18,
    }


    const route =  {
        "in": "0x865377367054516e17014CcdED1e7d814EDC9ce4",
        "pool": "0x8b83c4aA949254895507D09365229BC3a8c7f710",
        "out": "0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD",
        "display": "DOLA >> DOLA/sUSDS >> sUSDS "
      }
    const contracts = {
        curveRouter: await ethers.getContractAt("ICurveRouter", curveRouterAddress),
        in: await ethers.getContractAt("IERC20Metadata", route.in),
        out: await ethers.getContractAt("IERC20Metadata", route.out),
    };

    // console.log('usdcTgUSd' , await contracts.usdcTgUSd.symbol());
    // console.log('tgUsd', await contracts.tgUsd.symbol());
    // console.log('collat', await contracts.collat.symbol());

    // get the route and swap params
    const {routes, swapParams, zapPools} = routeParams(route.in, route.out, route.pool);
    const amount = parseEther("1");

   
 
    let amountOut: bigint | undefined;
    try {
        // @ts-ignore
        amountOut = await contracts.curveRouter.connect(user).get_dy(routes!, swapParams!, amount!, zapPools!);
        console.log("dy", {amountOut});
    } catch (e) {
        console.error(" ------> get_dy error");
    }

    await giveTokensoAddresss(user,route.in, amount,inData.slot,inData.isVyper);
    const balancInBefore = await contracts.in.balanceOf(userAddress);
    const balanceOutBefore = await contracts.out.balanceOf(userAddress);
    console.log("balance check ", {balanceOutBefore, balancInBefore});

    await contracts.in.connect(user).approve(curveRouterAddress, amount * 2n);
    try {
        console.log("exchange params ", routes, swapParams, amount, amountOut- (amountOut*10n/100n), zapPools, userAddress);
        // @ts-ignore
        await contracts.curveRouter.connect(user).exchange(routes!, swapParams!, amount,  amountOut- (amountOut*10n/100n), zapPools, userAddress);
    } catch (e) {
        console.error("------> exchange error", e.message);
    }
    const balanceInAfter = await contracts.in.balanceOf(userAddress);
    
    const balanceOutAfter = await contracts.out.balanceOf(userAddress);
    console.log(`in: ${balancInBefore} =>  ${balanceInAfter}`,`out: ${balanceOutBefore} =>  ${balanceOutAfter}`);

    //  pour liquider
    // exemple : test\tgUSD\unit\Liquidation\SecondaryLiquidation\SecondaryLiqdtCurveLp.t.sol ligne 71
}

const routeParams = (_in: AddressLike, _out: AddressLike, _pool: AddressLike) => {
    // https://docs.curve.fi/router/CurveRouterNG/#_route

    const routes: AddressLike[] = new Array(11).fill(ZeroAddress);
    {
        let i = 0;
        routes[i++] = _in; // LP collat  => token
        routes[i++] =_pool; // **SWAP**  LP collat  => USDC (remove liquidity)
        routes[i++] = _out; // USDC
        // routes[i++] = usdcTgUSd; //**SWAP** USDC >  tgUSD  POOL tgUSD-USDC
        // routes[i++] = tgUSD; // tgUSD
    }

    const swapParams: number[][] = new Array(5).fill(new Array(5).fill(0));
    {
        let i = 0;
        swapParams[i++] = [0, 1, 1, 1, 2]; // **SWAP**  LP collat  => USDC (remove liquidity)
        // swapParams[i++] = [0, 1, 1, 10, 2]; // **SWAP** USDC >  tgUSD  POOL tgUSD-USDC
    }

    const zapPools: AddressLike[] = new Array(5).fill(ZeroAddress);
    // zapPools[0] = marketData.collatAddress;
    // zapPools[1] = usdcTgUSd;
    //  console.log({ routes, swapParams, zapPools });
    return {routes, swapParams, zapPools};
};


export type RouteParams = {
    collateral: string;
    name: string;
    collateralOut: string;
    wTOkenPool?: string; // Leave empty for none wTOken route
    routes: {
        pool1: string;
        token1: string;
        pool2: string;
        token2: string;
        pool3: string;
        token3: string;
    };
    swapParams: number[][];
    zapPools: AddressLike[];
};

main();
