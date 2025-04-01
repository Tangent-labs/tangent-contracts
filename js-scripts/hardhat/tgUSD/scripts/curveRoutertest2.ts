import { ethers } from "hardhat";
import { } from "hardhat-tracer";
import addresses from "../../../../addresses-liquidation.json";
import { thiefConfig } from "defi-resources";
import { AddressLike, MaxUint256, parseEther, parseUnits, ZeroAddress } from "ethers";
import { giveTokensoAddresss } from "../../thief";
import { lpTokensINfo } from "../contexts/LiquidationRouteGeneration";

const curveRouterAddress = "0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e";
const USDC = thiefConfig.THIEF_TOKEN_CONFIG.USDC;

async function main() {
    const marketData = addresses.markets.find((m) => m.collatName === "USDC_fxUSD");
    if (!marketData) throw new Error("Market not found");

    const user = (await ethers.getSigners()).at(5);
    if (!user) throw new Error("User not found");
    const userAddress = await user.getAddress();


    const route =  {
        "in": "0xdac17f958d2ee523a2206206994597c13d831ec7",
        "pool": "0x4f493b7de8aac7d55f71853688b1f7c8f0243c85",
        "out": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        "display": "USDT >> USDT/USDC >> USDC "
      }

    const inData = lpTokensINfo.find((token) => token.address.toLowerCase() === route.in.toLowerCase());
    if(!inData){
        throw new Error("No inData found")
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
    const { routes, swapParams, zapPools } = routeParams(route.in, route.out, route.pool);

    const decimals = inData?.decimals || 18 ;
    const amount = parseUnits("100",decimals)

        try {
            const poolInfo = await _getPoolInfo(route.pool);
            console.log(poolInfo)
        
        }catch(e){}

    let amountOut: bigint | undefined;
    try {
        // @ts-ignore
        amountOut = await contracts.curveRouter.connect(user).get_dy(routes!, swapParams!, amount!, zapPools!);
        console.log("dy", { amountOut });
    } catch (e) {
        console.error(" ------> get_dy error");
    }

    if(!amountOut){
       // throw new Error("No amountOut found")
       amountOut = 0n
    }
    const balancInBeforeBefore = await contracts.in.balanceOf(userAddress);
    await giveTokensoAddresss(user, route.in, amount, inData.slot, inData.isVyper);
    const balancInBefore = await contracts.in.balanceOf(userAddress);
    const balanceOutBefore = await contracts.out.balanceOf(userAddress);
    console.log("balance check ", { balancInBeforeBefore,balanceOutBefore, balancInBefore });
    if(balancInBefore!==amount){
        throw new Error("balanceInBefore is not equal to amount")
    }

    try {
      //  await contracts.in.connect(user).approve(curveRouterAddress, 0n);
         await contracts.in.connect(user).approve(curveRouterAddress, MaxUint256 );
    }catch(e){
        console.error("------> approve error", (e as Error).message);
        return 
    }

    const allowance = await contracts.in.allowance(userAddress, curveRouterAddress);
    console.log(allowance)
    try {
        console.log("exchange params ", routes, swapParams, amount, 0n, zapPools, userAddress);
        // @ts-ignore
        await contracts.curveRouter.connect(user).exchange(routes!, swapParams!, amount, 0n, zapPools, userAddress);
    } catch (e  : unknown ) {
        console.error("------> exchange error", (e as Error).message);
    }
    const balanceInAfter = await contracts.in.balanceOf(userAddress);

    const balanceOutAfter = await contracts.out.balanceOf(userAddress);
    console.log(`in: ${balancInBefore} =>  ${balanceInAfter}`, `out: ${balanceOutBefore} =>  ${balanceOutAfter}`);

    //  pour liquider
    // exemple : test\tgUSD\unit\Liquidation\SecondaryLiquidation\SecondaryLiqdtCurveLp.t.sol ligne 71
}

const routeParams = (_in: AddressLike, _out: AddressLike, _pool: AddressLike) => {
    // https://docs.curve.fi/router/CurveRouterNG/#_route

    const routes: AddressLike[] = new Array(11).fill(ZeroAddress);
    {
        let i = 0;
        routes[i++] = _in; // LP collat  => token
        routes[i++] = _pool; // **SWAP**  LP collat  => USDC (remove liquidity)
        routes[i++] = _out; // USDC
        // routes[i++] = usdcTgUSd; //**SWAP** USDC >  tgUSD  POOL tgUSD-USDC
        // routes[i++] = tgUSD; // tgUSD
    }

    /* 
     The swap_type should be:
        1. for `exchange`,
        2. for `exchange_underlying`,
        3. for underlying exchange via zap: factory stable metapools with lending base pool `exchange_underlying`
            and factory crypto-meta pools underlying exchange (`exchange` method in zap)
        4. for coin -> LP token "exchange" (actually `add_liquidity`),
        5. for lending pool underlying coin -> LP token "exchange" (actually `add_liquidity`),
        6. for LP token -> coin "exchange" (actually `remove_liquidity_one_coin`)
        7. for LP token -> lending or fake pool underlying coin "exchange" (actually `remove_liquidity_one_coin`)
        8. for ETH <-> WETH, ETH -> stETH or ETH -> frxETH, stETH <-> wstETH, ETH -> wBETH
        9. for ERC4626 asset <-> share

        pool_type: 
            1 - stable, 2 - twocrypto, 3 - tricrypto, 4 - llamma
            10 - stable-ng, 20 - twocrypto-ng, 30 - tricrypto-ng
                        */  

    const swapParams: number[][] = new Array(5).fill(new Array(5).fill(0));
    {
        let i = 0;
        swapParams[i++] = [1, 0, 1, 1, 2]; // **SWAP**  LP collat  => USDC (remove liquidity)
        // swapParams[i++] = [0, 1, 1, 10, 2]; // **SWAP** USDC >  tgUSD  POOL tgUSD-USDC
    }

    const zapPools: AddressLike[] = new Array(5).fill(ZeroAddress);
    // zapPools[0] = marketData.collatAddress;
    // zapPools[1] = usdcTgUSd;
    //  console.log({ routes, swapParams, zapPools });
    return { routes, swapParams, zapPools };
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

async function _getPoolInfo(poolAddress: AddressLike): Promise<any> {
    const poolAbi = ["function coins(uint256) external view returns (address)",'function symbol() external view returns (string memory)','function totalSupply() external view returns (uint256)'];

    const poolContract = await ethers.getContractAt(poolAbi, poolAddress as string);
        const symbol = await poolContract.symbol();
        const totalSupply = await poolContract.totalSupply();
    const coinCount = 4;
    const coins: string[] = [];

    for (let i = 0; i < coinCount; i++) {
        try {
            const coinAddress = await poolContract.coins(i);
            coins.push(coinAddress);
        } catch { }
    }

   
    const coin1Contract = await ethers.getContractAt("IERC20", coins[0] as string);
    const coin2Contract = await ethers.getContractAt("IERC20", coins[1] as string);

    const balance1 = await coin1Contract.balanceOf(poolAddress);
    const balance2 = await  coin2Contract.balanceOf(poolAddress);

    let lp = ''



    return { coins, lp ,symbol,totalSupply,balance1,balance2};
}

main();
