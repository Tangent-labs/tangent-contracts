import { AddressLike,  parseEther,  ZeroAddress } from "ethers";
import fs from "fs";
import { ethers } from "hardhat";
import path from "path";
import { giveTokensoAddresss } from "../../thief";
import { commonERC20, thiefConfig } from "defi-resources";
// https://api.curve.fi/v1/documentation/#/Pools/get_getPools_big__blockchainId_

/*
    From :  CurveRouter v1.1 Code
        https://etherscan.io/address/0x16c6521dff6bab339122a0fe25a9116693265353#code
      
        pool_type: 
        1  stable, 
        2 - twocrypto, 
        3 - tricrypto, 
        4 - llamma
        10 - stable-ng, 
        20 - twocrypto-ng, 
        30 - tricrypto-ng

*/
const routerAddress = "0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e";

export const lpTokensINfo = [
    ...Object.entries(thiefConfig.THIEF_TOKEN_CONFIG).map(([key, value]) => ({
        token: key,
        address: value.address,
        slot: value.slotBalance,
        isVyper: value.isVyper,
    })),
      {
        token: 'USDC/fxUSD',
        address: '0x5018be882dcce5e3f2f3b0913ae2096b9b3fb61f',
        slot: 38,
        isVyper: true
      },
      {
        token: 'USDC/crvUSD',
        address: '0x4dece678ceceb27446b35c672dc7d61f30bad69e',
        slot: 20,
        isVyper: true
      },
      {
        token: 'USDT/crvUSD',
        address: '0x390f3595bca2df7d23783dfd126427cceb997bf4',
        slot: 20,
        isVyper: true
      },
      {
        token: 'sDAI/sUSDe',
        address: '0x167478921b907422f8e88b43c4af2b8bea278d3a',
        slot: 38,
        isVyper: true
      },
      {
        token: 'USDC/USDT',
        address: '0x4f493b7de8aac7d55f71853688b1f7c8f0243c85',
        slot: 38,
        isVyper: true
      },
      {
        token: 'USR/RLP',
        address: '0xc907ba505c2e1cbc4658c395d4a2c7e6d2c32656',
        slot: 19,
        isVyper: true
      },
      {
        token: 'frxUSD/USDe',
        address: '0xdbb1d219d84eacefb850ee04cacf2f1830934580',
        slot: 38,
        isVyper: true
      },
      {
        token: 'DOLA/USR',
        address: '0x38de22a3175708d45e7c7c64cd78479c8b56f76e',
        slot: 38,
        isVyper: true
      },
      {
        token: 'scrvUSD/sUSDe',
        address: '0xd29f8980852c2c76fc3f6e96a7aa06e0bedcc1b1',
        slot: 38,
        isVyper: true
      },
      {
        token: 'crvUSD/USDe',
        address: '0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E',
        slot: 1,
        isVyper: true
      },
      {
        token: 'USDe',
        address: '0x9d39a5de30e57443bff2a8307a4256c8797a3497',
        slot: 4,
        isVyper: false
      },
      {
        token: 'sUSDe',
        address: '0x9D39A5DE30e57443BfF2A8307A4256c8797A3497',
        slot: 4,
        isVyper: false
      },
      {
        token: 'sDAI',
        address: '0x83F20F44975D03b1b09e64809B757c47f942BEeA',
        slot: 1,
        isVyper: false
      }
];

export class LiquidationRouteGeneration {
    missing: MissingData = {
        symbols: new Set<string>(),
    };

    routeData?: RouteParams[];
    abis?: Record<string, AbiRow[]>;
    CSV_PATH = path.join(__dirname, "../data", "routes.csv");
    PATHS = {
        routesRaw: path.join(__dirname, "../data", "routes.json"),
        transfers: path.join(__dirname, "../data", "transfers.json"),
        verifiedRoutes: path.join(__dirname, "../data", "verifiedRoutes.json"),
        finalRoutes: path.join(__dirname, "../data", "finalRoutes.json"),
    };

    loadFile<T>(type: keyof typeof this.PATHS) {
        return JSON.parse(fs.readFileSync(this.PATHS[type], "utf-8")) as T;
    }

    saveFile<T>(type: keyof typeof this.PATHS, data: T) {
        fs.writeFileSync(this.PATHS[type], JSON.stringify(data, null, 2));
    }

    processTransfers(routeData: RouteParams[]) {
        const transferts = routeData.map((item) => {
            const transfers: Transfer[] = [];
            transfers.push({
                in: liquidationAssets[item.collateral],
                pool: liquidationAssets[item.collateral],
                out: liquidationAssets[item.collateralOut],
                display: `${item.collateral} >> ${item.collateral} >> ${item.collateralOut} `,
            });

            let lastIn = item.collateralOut;
            item?.routes?.forEach((route, index) => {
                const inToken = (index === 0 ? liquidationAssets[item.collateralOut] : transfers?.at(-1)?.out) || "not found";
                transfers.push({
                    in: inToken,
                    pool: liquidationAssets[route.pool],
                    out: liquidationAssets[route.out],
                    display: `${lastIn} >> ${route.pool} >> ${route.out} `,
                });
                lastIn = route.out;
            });

            return transfers;
        });
        return transferts;
    }

    validateCsv = () => {
        const names = new Set<string>();

        const csvData = fs.readFileSync(this.CSV_PATH, "utf8");

        const rows = csvData.split("\r").map((row: string) => row.split(";"));

        for (let i = 1; i < rows.length; i++) {
            const row = rows[i];
            if (!row[0].trim()) continue; // Skip rows without a starting collateral

            names.add(row[0].trim());
            names.add(row[1].trim());
            const dynamicRouteCount = 4;
            for (let j = 2; j <= dynamicRouteCount * 2; j += 2) {
                const pool = row[j]?.trim();
                const out = row[j + 1]?.trim();
                if (!pool || !out) continue;
                names.add(out);
                names.add(pool);
            }
        }
        names.forEach((name) => {
            if (!(liquidationAssets as any)[name]) {
                this.missing.symbols.add(name);
            }
        });
        console.log(names.size, " symbols found &  processed in the CSV file");
        return { valid: (this.missing?.symbols?.size || 0) === 0, mising: this.missing.symbols };
    };

    loadRoutesFromCSV() {
        // Read CSV file
        const csvData = fs.readFileSync(this.CSV_PATH, "utf8");

        // Parse CSV data
        const rows = csvData.split("\n").map((row: string) => row.split(";"));

        const routes = [];

        for (let i = 1; i < rows.length; i++) {
            const row = rows[i];
            if (!row[0].trim()) continue; // Skip rows without a starting collateral
            const collateral = row[0].trim();
            const collateralOut = row[1].trim();
            let wTOkenPool = undefined;
            const routeSteps = [];

            const dynamicRouteCount = 4;

            // let's get the dynamic portion of the route
            for (let j = 2; j <= dynamicRouteCount * 2; j += 2) {
                const pool = row[j]?.trim();
                const out = row[j + 1]?.trim();
                if (pool && out) {
                    routeSteps.push({ pool, out });
                    if (!wTOkenPool) wTOkenPool = out === "USDC" ? undefined : `w${out}`;
                }
            }

            routes.push({
                collateral,
                collateralOut,
                wTOkenPool,
                routes: routeSteps,
                swapParams: routeSteps.map(() => ({ poolType: 0, swapType: 0 })),
                zapPools: [],
                pools: [],
            } as RouteParams);
        }
        console.log(routes.length, ' routes found &  processed in the CSV file "this.routeData" setted');
        this.routeData = routes;
        return routes as RouteParams[];
    }

    // test routes with all the step
    async testRoute(verifiedRoutes: VerifiedRoutes, transfers: Transfer[][]) {
        const verifiedParamsMap = new Map<string, any>();
        verifiedRoutes.params.forEach((param: any) => {
            verifiedParamsMap.set(param.route.display.trim(), param.result);
        });

        const [deployer] = await ethers.getSigners();
        const router = await ethers.getContractAt("ICurveRouter", routerAddress, deployer)

        const stepResults: any[] = [];
        const errors: any[] = [];

        const amountIn = ethers.parseUnits("100", 9);
        await transfers.forEach(async (routeGroup) => {


            const routeAddresses = [];
            const swapParamsFull = [];
            routeAddresses.push(routeGroup[0].in);
            routeGroup.forEach(step => {
                if (!verifiedParamsMap.has(step.display)) {
                    errors.push({ step, error: "Missing verified route parameters" });
                    return;
                }

                routeAddresses.push(step.pool);
                routeAddresses.push(step.out);
                const stepParams = verifiedParamsMap.get(step.display.trim());
                swapParamsFull.push(stepParams.swapParams);
            })
            if (errors?.length) {
                return
            }
            while (routeAddresses.length < 11) {
                routeAddresses.push(ZeroAddress);
            }
            while (swapParamsFull.length < 5) {
                swapParamsFull.push([0, 0, 0, 0, 0]);
            }
            try {
                //@ts-ignore
                const output = await router.get_dy(routeAddresses, swapParamsFull, amountIn, [ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress]);
                stepResults.push({ route: routeGroup, output: output.toString(), params: { routeAddresses, swapParamsFull } });
            } catch (error: any) {
                errors.push({ route: routeGroup, error: error.message, params: { routeAddresses, swapParamsFull } });
            }
        })



        // Fill remaining slots with ZeroAddress and default swap params



        return { stepResults, errors };
    }

    async testOneRoute(routeGroup: Transfer[], routeAddresses: string[], swapParamsFull: number[][], amountIn: bigint) {
    }

    async testRouteSteps(transfers: Transfer[][]): Promise<VerifiedRoutes> {
       // const amountIn = ethers.parseUnits("100", 9);
        

         const amountIn = parseEther("10");
        const pools = new Map<string, Transfer>();
        const params = [];
        const errors = [];

        // Extract pools and their respective input/output tokens
        transfers.forEach((routeGroup: any[]) =>
            routeGroup.forEach((route) => {
                if (route.pool && route.in && route.out) {
                    pools.set(route.display, route);
                } else {
                    console.error("incomplete route found", route);
                }
            })
        );
        let coins: string[] = [];
        for (const [_, route] of pools.entries()) {
            try {
                coins = ['noONe']
                // No more RPC call; we use tokenIn & tokenOut from JSON
                const { coins: _coins ,symbol} = await this._getPoolInfo(route.pool);
                coins = _coins;
                console.log({poolSymbol : symbol})
                const result = await this._determineSwapParams(route.pool, route, amountIn);
                params.push({ route, coins: result.coins, swapParams: result.swapParams });
            } catch (error: any) {
                errors.push({ error: error.message, route, coins });
            }
        }
        return { params, errors };
    }

    async _getPoolInfo(poolAddress: AddressLike): Promise<{ coins: string[], lp: string ,symbol:string}> {
        const poolAbi = ["function coins(uint256) external view returns (address)",'function symbol() external view returns (string memory)'];

        const poolContract = await ethers.getContractAt(poolAbi, poolAddress as string);
            const symbol = await poolContract.symbol();
        const coinCount = 4;
        const coins: string[] = [];

        for (let i = 0; i < coinCount; i++) {
            try {
                const coinAddress = await poolContract.coins(i);
                coins.push(coinAddress);
            } catch { }
        }
        let lp = ''



        return { coins, lp ,symbol};
    }

    async _determineSwapParamsDy(poolAddress: AddressLike, route: Transfer, amountIn: bigint) {
        const { coins } = await this._getPoolInfo(poolAddress);

        const [deployer] = await ethers.getSigners();
        const router = await ethers.getContractAt("ICurveRouter", routerAddress)
        const routeAddresses = [route.in, poolAddress, route.out, ...Array(8).fill(ZeroAddress)];
        const ZEROS = [0, 0, 0, 0, 0];
        const swapTypes = [1, 2, 3, 4, 5, 6, 7, 8, 9];
        const poolTypes = [1, 2, 3, 4, 10, 20, 30];

        for (let i = 0; i < poolTypes.length; i++) {
            for (let j = 0; j < swapTypes.length; j++) {
                const currentSwapParams = [0, 1, swapTypes[j], poolTypes[i], coins.length];
                const swapParamsFull = [currentSwapParams, ZEROS, ZEROS, ZEROS, ZEROS];
                try {
                    //@ts-ignore
                    const output = await router.get_dy(routeAddresses, swapParamsFull, amountIn, [route.pool, ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress]);
                    if (output > 0n) {
                        return { swapType: swapTypes[j], poolType: poolTypes[i], swapParams: currentSwapParams, ...route, coins };
                    }
                } catch (e: any) {
                    // Ignore errors
                }
            }
        }
        throw new Error("No valid params found");
    }

    async _determineSwapParams(poolAddress: AddressLike, route: Transfer, amountIn: bigint) {
        const { coins } = await this._getPoolInfo(poolAddress);
        const zapPools= [ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress]
        const [deployer] = await ethers.getSigners();
        const router = await ethers.getContractAt("ICurveRouter", routerAddress)
        const routeAddresses = [route.in, poolAddress, route.out, ...Array(8).fill(ZeroAddress)];
        const ZEROS = [0, 0, 0, 0, 0];
    //    const swapTypes = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    //    const poolTypes = [1, 2, 3, 4, 10, 20, 30];
        const swapTypes = [ 9];
        const poolTypes = [0];
        const collateralTokenAddress = routeAddresses[0];
        const giveData = lpTokensINfo.reverse().find((token) => token.address.toLowerCase() === collateralTokenAddress.toLowerCase());

        const isTgtAsset = route.display.split(">>")[0].trim().endsWith('*')

       
        if (giveData || isTgtAsset) {  
           // console.log(`giveTokensoAddresss(deployer, ${collateralTokenAddress}, ${amountIn}, ${giveData?.slot || 0}, ${giveData ? giveData.isVyper :!isTgtAsset})`,giveData);
            await giveTokensoAddresss(deployer, collateralTokenAddress, amountIn, giveData?.slot || 0, !!giveData ? giveData.isVyper :!isTgtAsset);
        } else {
           // console.log("No initialCollateralBalance for  ", route.in, route.display);
            throw new Error(`No giveData for for  ${route.display} / ${route.in}`);
        }
        const outContract = await ethers.getContractAt("IERC20", route.out, deployer)
        const inContract = await ethers.getContractAt("IERC20", route.in, deployer);
        const initialInBalance = await inContract.balanceOf(deployer.address);
        if (initialInBalance === 0n) {
            console.log("❌ Error  > " ,  route.display , "\x1b[38;5;214m No initialCollateralBalance \x1b[0m");
            throw new Error(`No initialCollateralBalance for  ${route.display}`);
        }


        const txApprove = await inContract.connect(deployer).approve(routerAddress, amountIn);
        await txApprove.wait();
        const allowance = await inContract.allowance(deployer.address, routerAddress);
        if (allowance < amountIn) {
            console.log("❌ Error  > ",route.display, '\x1b[38;5;214m No allowance \x1b[0m');
            throw new Error(`No allowance for  ${route.display}`);
        }


        let indexPossibilities: [number, number][] = [[0,0],[0, 1], [1, 0],[1,1]];
        if (coins.length === 0) {
            indexPossibilities = [[0, 1]];
        }
        if (route.in === route.pool && route.in === route.pool) {
            indexPossibilities = [[0, 0],];
        }
        else if (route.in === route.pool) {
            indexPossibilities = [[0, 1], [0, 0]];
        }
        else if (route.out === route.pool) {
            indexPossibilities = [[0, 0], [1, 0]];
        }

        indexPossibilities = [[0,1]]
        if (coins?.length > 2) {
            console.error("Add case for more than 2 coins");
        }
        


        let testedParamsCount = 0;
        for (let i = 0; i < poolTypes.length; i++) {
            for (let j = 0; j < swapTypes.length; j++) {
                for (let k = 0; k < indexPossibilities.length; k++) {
                    const [inIndex, outIndex] = indexPossibilities[k];
                    const currentSwapParams = [inIndex, outIndex, swapTypes[j], poolTypes[i], coins.length];

                    console.log(currentSwapParams)
                    testedParamsCount++;
                    const swapParamsFull = [currentSwapParams, ZEROS, ZEROS, ZEROS, ZEROS];
                    let output = 0n;
                    let dy = 0n;
                    try {
                        const initialCollateralBalance = await inContract.balanceOf(deployer.address);
                        const initialOutBalance = await outContract.balanceOf(deployer.address);

                        //@ts-ignore
                        dy = await router.connect(deployer).get_dy(routeAddresses!, swapParamsFull!, amountIn!, zapPools!);
                        //min = await router.connect(deployer).get_dy(routeAddresses, swapParamsFull, amountIn, [ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress]);

                        //@ts-ignore
                        // 
                        
                       // const tx = await router.connect(deployer).exchange(routeAddresses, swapParamsFull, amountIn, min, [ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress]);
                        //await tx.wait();
                        //@ts-ignore
                        await router.connect(deployer).exchange(routeAddresses!, swapParamsFull!, amountIn, dy- (dy*10n/100n), zapPools, await deployer.getAddress());

                        const afterCollateralBalance = await inContract.balanceOf(deployer.address);
                        const afterOutBalance = await outContract.balanceOf(deployer.address);
                        if (afterCollateralBalance - initialCollateralBalance === 0n || afterOutBalance - initialOutBalance === 0n) {
                            //console.error("No balance change");
                            console.log("try", { swap: swapParamsFull.at(0), amountIn, error: "No balance change", output });
                            continue;
                        } else {
                            console.log('✅ Sucess > '  , route.display)
                            return { swapType: swapTypes[j], poolType: poolTypes[i], swapParams: currentSwapParams, ...route, coins };
                        }


                    } catch (e: any) {

                        if(currentSwapParams.map(s => s.toString()).join(',') === '0,1,9,0,0'){
                            console.log(routeAddresses, swapParamsFull,dy)
                            console.error(e, "error");
                        }
                    }
                }
            }
        }
        console.log('❌ Error  > ', route.display,"\x1b[38;5;214m No combnaison found \x1b[0m")
        throw new Error(`No valid params found, tested ${testedParamsCount} params`);
    }

    async loadDynamicAssets(addressesData: { lps: Record<string, string>; wStables: Record<string, string>; tokens: { tgUSD: string } }) {
        try {
            // Add LP tokens
            if (addressesData.lps) {
                Object.entries(addressesData.lps).forEach(([key, value]) => {
                    (liquidationAssets as any)[`${key}*`] = value;
                });
            }

            // Add wrapped stables
            if (addressesData.wStables) {
                Object.entries(addressesData.wStables).forEach(([key, value]) => {
                    (liquidationAssets as any)[`${key}*`] = value;
                });
            }
            liquidationAssets["tgUSD*"] = addressesData.tokens.tgUSD;

            console.log("Dynamic assets loaded successfully");
        } catch (error) {
            console.error("Error loading dynamic assets:", error);
            throw error;
        }
    }

    async testExchange(finalRoutes: FinalRoute) {
        const [deployer] = await ethers.getSigners();
        const router = await ethers.getContractAt("ICurveRouter", routerAddress, deployer)
        const tgUsdContract = await ethers.getContractAt("IERC20", liquidationAssets['tgUSD*'], deployer)

        const results = [];
        const errors = [];


        let i = 0;
        for (const routeResult of finalRoutes.stepResults) {
            //  if (i++ > 0) continue;

            try {



                const amountIn = ethers.parseUnits("10", 18);
                // Get initial balances
                const inTokenAddress = routeResult.params.routeAddresses[0];
                const { lp } = await this._getPoolInfo(inTokenAddress);
                console.log('lp', lp);
                const giveData = lpTokensINfo.find((token) => token.address.toLowerCase() === inTokenAddress.toLowerCase());
                if (giveData) {
                    await giveTokensoAddresss(deployer, giveData.address, amountIn, giveData.slot, true);
                } else {
                    console.log("No give data found", inTokenAddress);
                    errors.push(`No give data found ${inTokenAddress}`);
                    continue;

                }

                const inTokenContract = await ethers.getContractAt("IERC20", inTokenAddress, deployer);
                const txApprove = await inTokenContract.approve(routerAddress, amountIn);
                await txApprove.wait();
                const initialOutBalance = await tgUsdContract.balanceOf(deployer.address);
                const initialInBalance = await inTokenContract.balanceOf(deployer.address);
                // const initialTgUSDBalance = await tgUSDContract.balanceOf(deployer.address);
                if (initialInBalance === 0n) {
                    errors.push(`No initial In Balance  ${inTokenAddress}`);
                    continue;

                }

                // Execute the exchange
                // @ts-ignore
                const amountMin = await router.get_dy(routeResult.params.routeAddresses, routeResult.params.swapParamsFull, amountIn, [
                    ZeroAddress,
                    ZeroAddress,
                    ZeroAddress,
                    ZeroAddress,
                    ZeroAddress,
                ]);

                //@ts-ignore
                const amountOut = await router.exchange(routeResult.params.routeAddresses,
                    routeResult.params.swapParamsFull,
                    amountIn,
                    amountMin,
                    [ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress],
                    deployer.address
                );

                // Get final balances
                const finalInBalance = await inTokenContract.balanceOf(deployer.address);
                const finalOutBalance = await tgUsdContract.balanceOf(deployer.address);

                if (finalInBalance - initialInBalance === 0n) {
                    //console.log("No change in balance", { amountOut, initialInBalance, finalInBalance });
                    errors.push({
                        route: routeResult.route.map((step) => step.display).join(" -> "),
                        error: "No change in balance",
                        params: routeResult.params,
                        amountOut: amountOut.toString(),
                    });
                    continue;
                }

                results.push({
                    route: routeResult.route.map((step) => step.display).join(" -> "),
                    params: { routeAddresses: routeResult.params.routeAddresses },
                    success: true,
                    balanceChanges: {
                        collateral: {
                            before: initialInBalance.toString(),
                            after: finalInBalance.toString(),
                            difference: (initialInBalance - finalInBalance).toString(),
                        },
                        tgUSD: {
                            before: initialOutBalance.toString(),
                            after: finalOutBalance.toString(),
                            difference: (initialOutBalance - finalOutBalance).toString(),
                        },

                    },
                    expectedOutput: routeResult.output,
                });
            } catch (error: any) {
                //console.error({ code: error.code, message: error.message }, "error");
                errors.push({
                    route: routeResult.route.map((step) => step.display).join(" -> "),
                    error: error.message,
                    params: routeResult.params,
                });
            }
        }

        return {
            results,
            errors,
            summary: {
                totalRoutes: finalRoutes.stepResults.length,
                successfulRoutes: results.length,
                failedRoutes: errors.length,
            },
        };
    }
}

export const liquidationAssets: Record<string, string> = {
    "sDAI savings": commonERC20.sDAI,
    DAI: commonERC20.DAI,
    sDAI: commonERC20.sDAI,
    USDT:  commonERC20.USDT,
    sUSDS: commonERC20.sUSDS,
    scrvUSD: commonERC20.scrvUSD,
    FRAX: commonERC20.FRAX,
    deUSD: commonERC20.deUSD,
    DOLA: commonERC20.DOLA,
    USR: commonERC20.USR, 
    USDC: commonERC20.USDC,
    crvUSD: commonERC20.crvUSD,
    frxUSD: commonERC20.frxUSD,
    USDe: commonERC20.USDe,
    sUSDe: commonERC20.sUSDe,
    FRAXBP: "0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC",
    /* Pools */
    FRAXUSDe: "0x5dc1bf6f1e983c0b21efb003c105133736fa0743",
    fraxusdc: "0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2",
    "DOLA/USR": "0x38de22a3175708d45e7c7c64cd78479c8b56f76e",
    "DOLA/FRAXBP": "0xe57180685e3348589e9521aa53af0bcd497e884d",
    "crvUSD/fxUSD": "0x8ffc7b89412efd0d17edea2018f6634ea4c2fcb2",
    "deUSD/USDC": "0x5f6c431ac417f0f430b84a666a563fabe681da94",
    "deUSD/DOLA": "0x6691dbb44154a9f23f8357c56fc9ff5548a8bdc4",
    "USDe-USDC": "0x02950460e2b9529d0e00284a5fa2d7bdf3fa4d72",
    "frxUSD/USDe": "0xdbb1d219d84eacefb850ee04cacf2f1830934580",
    "FRAX/frxUSD": "0xbbaf8b2837cbbc7146f5bc978d6f84db0be1cacc",
    "USDC/fxUSD": "0x5018be882dcce5e3f2f3b0913ae2096b9b3fb61f",
    "USDC/crvUSD": "0x4dece678ceceb27446b35c672dc7d61f30bad69e",
    "crvUSD/USDC": "0x4dece678ceceb27446b35c672dc7d61f30bad69e",
    "USDT/crvUSD": "0x390f3595bca2df7d23783dfd126427cceb997bf4",
    "sDAI/sUSDe": "0x167478921b907422f8e88b43c4af2b8bea278d3a",
    "USDC/USDT": "0x4f493b7de8aac7d55f71853688b1f7c8f0243c85",
    "USDT/USDC": "0x4f493b7de8aac7d55f71853688b1f7c8f0243c85",
    "USR/RLP": "0xc907ba505c2e1cbc4658c395d4a2c7e6d2c32656",
    "scrvUSD/sUSDe": "0xd29f8980852c2c76fc3f6e96a7aa06e0bedcc1b1",
    "USR/USDC": "0x3ee841f47947fefbe510366e4bbb49e145484195",
    "DAI/USDC/USDT": "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7",
    "scrvUSD savings": "0x0655977FEb2f289A4aB78af67BAB0d17aAb84367",
    "USDC/USDe": "0x02950460e2b9529d0e00284a5fa2d7bdf3fa4d72",
    "FRAX/USDC": "0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2",
    "crvUSD/DOLA": "0x8272E1A3dBef607C04AA6e5BD3a1A134c8ac063B",
    "crvUSD/FRAX": "0x0CD6f267b2086bea681E922E19D40512511BE538",
    "DOLA/sUSDe": "0x744793B5110f6ca9cC7CDfe1CE16677c3Eb192ef",
    "sDAI/FRAX": "0xcE6431D21E3fb1036CE9973a3312368ED96F5CE7",
    "deUSD/USDT": "0x7C4e143B23D72E6938E06291f705B5ae3D5c7c7C",
    "crvUSD/USDT": "0x390f3595bca2df7d23783dfd126427cceb997bf4",
    "sUSDS/frxUSD": "0x81A2612F6dEA269a6Dd1F6DeAb45C5424EE2c4b7",
    "DOLA/sUSDS": "0x8b83c4aA949254895507D09365229BC3a8c7f710",
    "crvUSD/USDe": "0xF55B0f6F2Da5ffDDb104b58a60F2862745960442",
    "DOLA/scrvUSD": "0xff17dAb22F1E61078aBa2623c89cE6110E878B3c",
    "scrvUSD/sUSDS": "0xfD1627E3f3469C8392C8c3A261D8F0677586e5e1",
};

export type RouteParams = {
    collateral: keyof typeof liquidationAssets;
    collateralOut: keyof typeof liquidationAssets;
    wTOkenPool?: string; // Leave empty for none wTOken route
    routes?: { pool: keyof typeof liquidationAssets; out: keyof typeof liquidationAssets }[];
    swapParams: { poolType: number; swapType: number }[];
    zapPools: AddressLike[];
    pools: (PoolCurveData | undefined)[];
};

export type PoolCurveData = {
    id: string;
    address: AddressLike;
    coinsAddresses: [AddressLike, AddressLike];
    registryId: string;
    symbol: string;
    in?: AddressLike;
    out?: AddressLike;
    inINdex: number;
    outIndex: number;
};

type AbiRow = { name: string; type: string; outputs: any[] };
type MissingData = {
    symbols: Set<String>;
};

export interface Transfer {
    in: string;
    pool: string;
    out: string;
    display: string;
}

type VerifiedRouteParams = {

    swapParams: number[];
    coins: string[];
};

type VerifiedRoute = {
    route: Transfer;
    result: VerifiedRouteParams;
};

export type VerifiedRoutes = {
    params: VerifiedRoute[];
    errors: { route: Transfer; error: string }[];
};

type FinalRouteStep = {
    in: string;
    pool: string;
    out: string;
    display: string;
};

type FinalRouteParams = {
    routeAddresses: string[];
    swapParamsFull: number[][];
};

type FinalRouteResult = {
    route: FinalRouteStep[];
    output: string;
    params: FinalRouteParams;
};

export type FinalRoute = {
    stepResults: FinalRouteResult[];
};
