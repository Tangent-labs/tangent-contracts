import {AddressLike, getAddress, ZeroAddress} from "ethers";
import fs from "fs";
import {ethers} from "hardhat";
import path from "path";

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
const routerAddress = "0x16c6521dff6bab339122a0fe25a9116693265353";
const routerAbi = ["function get_dy(address[11], uint256[5][5], uint256, address[5]) external view returns (uint256)"];

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
        console.log(csvData.split("\r").join("------>"), " characters found in the CSV file");
        const rows = csvData.split("\r").map((row: string) => row.split(";"));
        console.log(rows.length, " rows found in the CSV file");

        for (let i = 1; i < rows.length; i++) {
            const row = rows[i];
            if (!row[0].trim()) continue; // Skip rows without a starting collateral

            names.add(row[0].trim());
            names.add(row[1].trim());
            const dynamicRouteCount = 4;
            for (let j = 2; j < dynamicRouteCount * 2; j += 2) {
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
        return {valid: (this.missing?.symbols?.size || 0) === 0, mising: this.missing.symbols};
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
            for (let j = 2; j < dynamicRouteCount * 2; j += 2) {
                const pool = row[j]?.trim();
                const out = row[j + 1]?.trim();
                if (pool && out) {
                    routeSteps.push({pool, out});
                    if (!wTOkenPool) wTOkenPool = out === "USDC" ? undefined : `w${out}`;
                }
            }

            routes.push({
                collateral,
                collateralOut,
                wTOkenPool,
                routes: routeSteps,
                swapParams: routeSteps.map(() => ({poolType: 0, swapType: 0})),
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
            verifiedParamsMap.set(param.route.display, param.result);
        });

        const provider = ethers.provider;
        const router = new ethers.Contract(routerAddress, routerAbi, provider);

        const stepResults = [];
        const errors = [];

        for (const routeGroup of transfers) {
            const routeAddresses = [];
            const swapParamsFull = [];
            const amountIn = ethers.parseUnits("100", 9);
            routeAddresses.push(routeGroup[0].pool);

            for (const step of routeGroup) {
                const poolAddress = step.pool.toLowerCase();
                if (!verifiedParamsMap.has(step.display)) {
                    errors.push({step, error: "Missing verified route parameters"});
                    continue;
                }

                const stepParams = verifiedParamsMap.get(step.display);
                routeAddresses.push(poolAddress, step.out);
                swapParamsFull.push(stepParams.swapParams);
            }

            // Fill remaining slots with ZeroAddress and default swap params
            while (routeAddresses.length < 11) {
                routeAddresses.push(ZeroAddress);
            }
            while (swapParamsFull.length < 5) {
                swapParamsFull.push([0, 0, 0, 0, 0]);
            }

            try {
                const output = await router.get_dy(routeAddresses, swapParamsFull, amountIn, [ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress]);
                stepResults.push({route: routeGroup, output: output.toString(), params: {routeAddresses, swapParamsFull}});
            } catch (error: any) {
                errors.push({route: routeGroup, error: error.message, params: {routeAddresses, swapParamsFull}});
            }
        }
        return {stepResults, errors};
    }

    // find the parameters for each
    async testRouteSteps(transfers: Transfer[][]): Promise<VerifiedRoutes> {
        const amountIn = ethers.parseUnits("100", 9);
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

        for (const [_, route] of pools.entries()) {
            try {
                // No more RPC call; we use tokenIn & tokenOut from JSON

                const result = await this._determineSwapParams(route.pool, route, amountIn);
                params.push({route, result});
            } catch (error: any) {
                errors.push({error: error.message, route});
            }
        }
        return {params, errors};
    }

    async _getPoolInfo(poolAddress: AddressLike): Promise<{coins: string[]}> {
        const poolAbi = ["function coins(uint256) external view returns (address)"];

        const poolContract = await ethers.getContractAt(poolAbi, poolAddress as string);

        const coinCount = 4;
        const coins: string[] = [];

        for (let i = 0; i < coinCount; i++) {
            try {
                const coinAddress = await poolContract.coins(i);
                coins.push(coinAddress);
            } catch {}
        }
        return {coins};
    }

    async _determineSwapParams(poolAddress: AddressLike, route: Transfer, amountIn: bigint) {
        const {coins} = await this._getPoolInfo(poolAddress);

        const [deployer] = await ethers.getSigners();
        const router = new ethers.Contract(routerAddress, routerAbi, deployer);
        const routeAddresses = [route.in, poolAddress, route.out, ...Array(8).fill(ZeroAddress)];
        const ZEROS = [0, 0, 0, 0, 0];
        const swapTypes = [1, 2, 3, 4, 5, 6, 7, 8, 9];
        const poolTypes = [1, 2, 3, 4, 10, 20, 30];

        for (let i = 0; i < poolTypes.length; i++) {
            for (let j = 0; j < swapTypes.length; j++) {
                const currentSwapParams = [0, 1, poolTypes[i], swapTypes[j], coins.length];
                const swapParamsFull = [currentSwapParams, ZEROS, ZEROS, ZEROS, ZEROS];
                try {
                    const output = await router.get_dy(routeAddresses, swapParamsFull, amountIn, [ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress]);
                    if (output > 0n) {
                        return {swapType: swapTypes[j], poolType: poolTypes[i], swapParams: currentSwapParams, ...route, coins};
                    }
                } catch (e: any) {
                    // Ignore errors
                }
            }
        }
        throw new Error("No valid params found");
    }

    async loadDynamicAssets(addressesData: {lps: Record<string, string>; wStables: Record<string, string>; tokens: {tgUSD: string}}) {
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
}

export const liquidationAssets: Record<string, string> = {
    "DOLA/USR": "0x38de22a3175708d45e7c7c64cd78479c8b56f76e",
    "DOLA/FRAXBP": "0xe57180685e3348589e9521aa53af0bcd497e884d",
    FRAXBP: "0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC",
    "crvUSD/fxUSD": "0x8ffc7b89412efd0d17edea2018f6634ea4c2fcb2",
    "deUSD/USDC": "0x5f6c431ac417f0f430b84a666a563fabe681da94",
    "deUSD/DOLA": "0x6691dbb44154a9f23f8357c56fc9ff5548a8bdc4",
    crvUSD: "0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E",
    frxUSD: "0xcacd6fd266af91b8aed52accc382b4e165586e29",
    USDe: "0x9d39a5de30e57443bff2a8307a4256c8797a3497",
    DOLA: "0x865377367054516e17014CcdED1e7d814EDC9ce4",
    USR: "0x66a1e37c9b0eaddca17d3662d6c05f4decf3e110",
    USDC: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    "USDe-USDC": "0x02950460e2b9529d0e00284a5fa2d7bdf3fa4d72",
    "frxUSD/USDe": "0xdbb1d219d84eacefb850ee04cacf2f1830934580",
    "FRAX/frxUSD": "0xbbaf8b2837cbbc7146f5bc978d6f84db0be1cacc",
    FRAXUSDe: "0x5dc1bf6f1e983c0b21efb003c105133736fa0743",
    fraxusdc: "0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2",
    "USDC/fxUSD": "0x5018be882dcce5e3f2f3b0913ae2096b9b3fb61f",
    "USDC/crvUSD": "0x4dece678ceceb27446b35c672dc7d61f30bad69e",
    "crvUSD/USDC": "0x4dece678ceceb27446b35c672dc7d61f30bad69e",
    "USDT/crvUSD": "0x390f3595bca2df7d23783dfd126427cceb997bf4",
    "sDAI/sUSDe": "0x167478921b907422f8e88b43c4af2b8bea278d3a",
    "USDC/USDT": "0x4f493b7de8aac7d55f71853688b1f7c8f0243c85",
    "USDT/USDC": "0x4f493b7de8aac7d55f71853688b1f7c8f0243c85",
    "USR/RLP": "0xc907ba505c2e1cbc4658c395d4a2c7e6d2c32656",
    "scrvUSD/sUSDe": "0xd29f8980852c2c76fc3f6e96a7aa06e0bedcc1b1",
    deUSD: "0x15700b564ca08d9439c58ca5053166e8317aa138",
    "USR/USDC": "0x3ee841f47947fefbe510366e4bbb49e145484195",
    "DAI/USDC/USDT": "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7",
    "scrvUSD savings": "0x0655977FEb2f289A4aB78af67BAB0d17aAb84367",
    "sDAI savings": "0x83F20F44975D03b1b09e64809B757c47f942BEeA",
    DAI: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    sDAI: "0x83F20F44975D03b1b09e64809B757c47f942BEeA",
    USDT: "0xdac17f958d2ee523a2206206994597c13d831ec7",
    scrvUSD: "0x0655977feb2f289a4ab78af67bab0d17aab84367",
    "USDC/USDe": "0x02950460e2b9529d0e00284a5fa2d7bdf3fa4d72",
    "FRAX/USDC": "0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2",
    FRAX: "0x853d955aCEf822Db058eb8505911ED77F175b99e",
    "crvUSD/DOLA": "0x8272E1A3dBef607C04AA6e5BD3a1A134c8ac063B",
    "crvUSD/FRAX": "0x0CD6f267b2086bea681E922E19D40512511BE538",
    sUSDe: "0x9D39A5DE30e57443BfF2A8307A4256c8797A3497",
    "DOLA/sUSDe": "0x744793B5110f6ca9cC7CDfe1CE16677c3Eb192ef",
    "sDAI/FRAX": "0xcE6431D21E3fb1036CE9973a3312368ED96F5CE7",
    "deUSD/USDT": "0x7C4e143B23D72E6938E06291f705B5ae3D5c7c7C",
    "crvUSD/USDT": "0x390f3595bca2df7d23783dfd126427cceb997bf4",
    "sUSDS/frxUSD": "0x81A2612F6dEA269a6Dd1F6DeAb45C5424EE2c4b7",
    sUSDS: "0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD",
    "DOLA/sUSDS": "0x8b83c4aA949254895507D09365229BC3a8c7f710",
    "crvUSD/USDe": "0xF55B0f6F2Da5ffDDb104b58a60F2862745960442",
    "DOLA/scrvUSD": "0xff17dAb22F1E61078aBa2623c89cE6110E878B3c",
    "scrvUSD/sUSDS": "0xfD1627E3f3469C8392C8c3A261D8F0677586e5e1",
};

export type RouteParams = {
    collateral: keyof typeof liquidationAssets;
    collateralOut: keyof typeof liquidationAssets;
    wTOkenPool?: string; // Leave empty for none wTOken route
    routes?: {pool: keyof typeof liquidationAssets; out: keyof typeof liquidationAssets}[];
    swapParams: {poolType: number; swapType: number}[];
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

type AbiRow = {name: string; type: string; outputs: any[]};
type MissingData = {
    symbols: Set<String>;
};

interface Transfer {
    in: string;
    pool: string;
    out: string;
    display: string;
}

type VerifiedRouteParams = {
    swapType: number;
    poolType: number;
    swapParams: number[];
    in: string;
    pool: string;
    out: string;
    display: string;
    coins: string[];
};

type VerifiedRoute = {
    route: Transfer;
    result: VerifiedRouteParams;
};

export type VerifiedRoutes = {
    params: VerifiedRoute[];
    errors: {route: Transfer; error: string}[];
};
