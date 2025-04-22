import {AddressLike, MaxUint256, ZeroAddress} from "ethers";
import fs from "fs";
import {ethers} from "hardhat";
import path from "path";
import {giveTokensoAddresss} from "../../thief";
import {commonERC20, routers, thiefConfig} from "defi-resources";
import {SignerWithAddress} from "@nomicfoundation/hardhat-ethers/signers";
import {
    FRAX_USDC_LP,
    CRV_LP_FRAX_USDe,
    CRV_DUO_FRAXBP_POOL,
    CRV_DUO_DOLA_USR,
    CRV_DUO_DOLA_FRAXBP,
    CRV_DUO_crvUSD_fxUSD,
    CRV_DUO_deUSD_USDC,
    CRV_DUO_deUSD_DOLA,
    CRV_DUO_USDe_USDC,
    CRV_DUO_FRAX_frxUSD,
    CRV_DUO_DOLA_sUSDe,
    CRV_DUO_deUSD_USDT,
    CRV_DUO_sUSDS_frxUSD,
    CRV_DUO_DOLA_sUSDS,
    CRV_DUO_DOLA_scrvUSD,
    CRV_DUO_scrvUSD_sUSDS,
    CRV_DUO_USDC_crvUSD,
    CRV_DUO_USDT_crvUSD,
    CRV_DUO_USR_RLP,
    CRV_DUO_frxUSD_USDe,
    CRV_DUO_scrvUSD_sUSDe,
    CRV_DUO_crvUSD_USDe,
    CRV_TRI_DAI_USDC_USDT,
    CRV_DUO_USR_USDC,
    CRV_DUO_USDC_USDT,
} from "defi-resources/build/ressources/lps/curve";

// https://api.curve.fi/v1/documentation/#/Pools/get_getPools_big__blockchainId_

/*
    From :  CurveRouter v1.2 Code
        https://etherscan.io/address/0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e#code
      
        pool_type: 
        1  stable, 
        2 - twocrypto, 
        3 - tricrypto, 
        4 - llamma
        10 - stable-ng, 
        20 - twocrypto-ng, 
        30 - tricrypto-ng

*/
const routerAddress = routers.CURVE_V1_2_ROUTER;

export const lpTokensINfo = [
    ...Object.entries(thiefConfig.THIEF_TOKEN_CONFIG).map(([key, value]) => ({
        token: key,
        address: value.address,
        slot: value.slotBalance,
        isVyper: value.isVyper,
        decimals: value.decimals,
    })),
    {
        token: "deUSD",
        address: "0x15700b564ca08d9439c58ca5053166e8317aa138",
        slot: 0,
        isVyper: false,
        decimals: 18,
    },
    {
        token: "sUSDS",
        address: "0xa3931d71877c0e7a3148cb7eb4463524fec27fbd",
        slot: 2,
        isVyper: false,
        decimals: 18,
    },
    {
        token: "scrvUSD",
        address: "0x0655977feb2f289a4ab78af67bab0d17aab84367",
        slot: 18,
        isVyper: true,
        decimals: 18,
    },
    {
        token: "USDC/fxUSD",
        address: "0x8ffc7b89412efd0d17edea2018f6634ea4c2fcb2",
        slot: 38,
        isVyper: true,
        decimals: 18,
    },
    {
        token: "USDC/crvUSD",
        address: "0x4dece678ceceb27446b35c672dc7d61f30bad69e",
        slot: 20,
        isVyper: true,
        decimals: 18,
    },
    {
        token: "USDT/crvUSD",
        address: "0x390f3595bca2df7d23783dfd126427cceb997bf4",
        slot: 20,
        isVyper: true,
        decimals: 18,
    },
    {
        token: "sDAI/sUSDe",
        address: "0x167478921b907422f8e88b43c4af2b8bea278d3a",
        slot: 38,
        isVyper: true,
        decimals: 18,
    },
    {
        token: "USDC/USDT",
        address: "0x4f493b7de8aac7d55f71853688b1f7c8f0243c85",
        slot: 38,
        isVyper: true,
        decimals: 18,
    },
    {
        token: "USR/RLP",
        address: "0xc907ba505c2e1cbc4658c395d4a2c7e6d2c32656",
        slot: 19,
        isVyper: true,
        decimals: 18,
    },
    {
        token: "frxUSD/USDe",
        address: "0xdbb1d219d84eacefb850ee04cacf2f1830934580",
        slot: 38,
        isVyper: true,
        decimals: 18,
    },
    {
        token: "DOLA/USR",
        address: "0x38de22a3175708d45e7c7c64cd78479c8b56f76e",
        slot: 38,
        isVyper: true,
        decimals: 18,
    },
    {
        token: "scrvUSD/sUSDe",
        address: "0xd29f8980852c2c76fc3f6e96a7aa06e0bedcc1b1",
        slot: 38,
        isVyper: true,
        decimals: 18,
    },
    {
        token: "crvUSD/USDe",
        address: "0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E",
        slot: 1,
        isVyper: true,
        decimals: 18,
    },
    {
        token: "USDe",
        address: "0x9d39a5de30e57443bff2a8307a4256c8797a3497",
        slot: 4,
        isVyper: false,
        decimals: 18,
    },
    {
        token: "sUSDe",
        address: "0x9D39A5DE30e57443BfF2A8307A4256c8797A3497",
        slot: 4,
        isVyper: false,
        decimals: 18,
    },
    {
        token: "sDAI",
        address: "0x83F20F44975D03b1b09e64809B757c47f942BEeA",
        slot: 1,
        isVyper: false,
        decimals: 18,
    },
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
            for (let j = 2; j <= dynamicRouteCount * 2; j += 2) {
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
            verifiedParamsMap.set(param.route.display.trim(), param.result.swapParams);
        });

        const [, , , , , user] = await ethers.getSigners();
        const router = await ethers.getContractAt("ICurveRouter", routerAddress, user);

        const results: RouteResult[] = [];
        const errors: any[] = [];

        const amountIn = ethers.parseUnits("100", 18);
        const promises = transfers.map(async (routeGroup) => {
            const routeAddresses = [];
            const swapParamsFull = [];
            routeAddresses.push(routeGroup[0].in);
            routeGroup.forEach((step) => {
                if (!verifiedParamsMap.has(step.display.trim())) {
                    errors.push({step, error: `Missing verified route parameters ${step.display.trim()}`});
                    return;
                }
                routeAddresses.push(step.pool);
                routeAddresses.push(step.out);
                const stepParams = verifiedParamsMap.get(step.display.trim());
                swapParamsFull.push(stepParams);
            });
            if (errors?.length) {
                return;
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
                if (output.toString() === "0") {
                    errors.push({route: routeGroup.map((r) => r.display).join(" >> "), error: "No output", params: {routeAddresses, swapParams: swapParamsFull}});
                    return;
                }
                results.push({
                    start: routeGroup.at(0)!.in!,
                    end: routeGroup.at(-1)!.out!,

                    params: {routeAddresses, swapParamsFull: swapParamsFull},
                    route: routeGroup.map((r) => r.display).join(" >> "),
                });
            } catch (error: any) {
                console.log("error", error.message);
                errors.push({route: routeGroup.map((r) => r.display).join(" >> "), error: error.message, params: {routeAddresses, swapParamsFull}});
            }
        });

        await Promise.all(promises);
        return {results, errors};
    }

    async testRouteSteps(transfers: Transfer[][]): Promise<VerifiedRoutes> {
        const pools = new Map<string, Transfer>();
        const params: VerifiedRoute[] = [];
        const errors: {route: Transfer; error: string}[] = [];

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
                coins = ["noONe"];
                // No more RPC call; we use tokenIn & tokenOut from JSON
                const {coins: _coins, symbol} = await this._getPoolInfo(route.pool);
                coins = _coins;
                const result = await this._determineSwapParams(route.pool, route);
                params.push({route, result: {coins: result.coins, swapParams: result.swapParams}});
            } catch (error: any) {
                errors.push({error: error.message, route});
            }
        }
        return {params, errors} as VerifiedRoutes;
    }

    async _getPoolInfo(poolAddress: AddressLike): Promise<{coins: string[]; lp: string; symbol: string}> {
        const poolAbi = ["function coins(uint256) external view returns (address)", "function symbol() external view returns (string memory)"];

        const poolContract = await ethers.getContractAt(poolAbi, poolAddress as string);
        let symbol = "";
        try {
            symbol = await poolContract.symbol();
        } catch (e) {}
        const coinCount = 4;
        const coins: string[] = [];

        for (let i = 0; i < coinCount; i++) {
            try {
                const coinAddress = await poolContract.coins(i);
                coins.push(coinAddress);
            } catch {}
        }
        let lp = "";

        return {coins, lp, symbol};
    }

    async prepareUserForExchange(route: Transfer, user: SignerWithAddress, amount: number) {
        const giveData = lpTokensINfo.reverse().find((token) => token.address.toLowerCase() === route.in.toLowerCase());
        const isTgtAsset = route.display.split(">>")[0].trim().endsWith("*");
        const inContract = await ethers.getContractAt("IERC20Metadata", route.in);
        let initialInBalance = await inContract.balanceOf(user.address);
        const amountIn = ethers.parseUnits(amount.toString(), giveData?.decimals || 18);
        if (giveData || isTgtAsset) {
            if (initialInBalance < amountIn) {
                await giveTokensoAddresss(user, route.in, amountIn, giveData?.slot || 0, !!giveData ? giveData.isVyper : !isTgtAsset);
                initialInBalance = await inContract.balanceOf(user.address);
            }
        } else {
            throw new Error(`No giveData for for  ${route.display} / ${route.in}`);
        }
        try {
            {
                const txApprove = await inContract.connect(user).approve(routerAddress, 0);
                await txApprove.wait();
            }
            const txApprove = await inContract.connect(user).approve(routerAddress, MaxUint256);
            await txApprove.wait();
        } catch (e) {
            throw new Error(`Approve error for  ${route.display} : ${(e as Error).message}`);
        }

        const allowance = await inContract.allowance(user.address, routerAddress);
        if (allowance < amountIn) {
            throw new Error(`No allowance for  ${route.display}`);
        }
        return {initialInBalance, inContract, isTgtAsset, giveData, amountIn};
    }

    async _determineSwapParams(poolAddress: AddressLike, route: Transfer) {
        const {coins} = await this._getPoolInfo(poolAddress);
        const zapPools = [ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress] as AddressLike[];
        const [, , , , , , , , user] = await ethers.getSigners();
        const router = await ethers.getContractAt("ICurveRouter", routerAddress);
        const routeAddresses = [route.in, poolAddress, route.out, ...Array(8).fill(ZeroAddress)] as AddressLike[];
        const ZEROS = [0, 0, 0, 0, 0];
        const swapTypes = [1, 2, 3, 4, 5, 6, 7, 8, 9];
        const poolTypes = [1, 2, 3, 4, 10, 20, 30];

        const {inContract, amountIn} = await this.prepareUserForExchange(route, user, 10);
        const outContract = await ethers.getContractAt("IERC20", route.out, user);

        let indexPossibilities: [number, number][] = [];

        const maxIndex = !coins.length ? 2 : coins.length - 1;
        indexPossibilities = [];
        for (let i = 0; i <= maxIndex; i++) {
            for (let j = 0; j <= maxIndex; j++) {
                indexPossibilities.push([i, j]);
            }
        }

        let testedParamsCount = 0;
        for (let i = 0; i < poolTypes.length; i++) {
            for (let j = 0; j < swapTypes.length; j++) {
                for (let k = 0; k < indexPossibilities.length; k++) {
                    const [inIndex, outIndex] = indexPossibilities[k];
                    const currentSwapParams = [inIndex, outIndex, swapTypes[j], poolTypes[i], coins.length === 1 ? 0 : coins.length] as number[];
                    testedParamsCount++;
                    const swapParamsFull = [currentSwapParams, ZEROS, ZEROS, ZEROS, ZEROS];
                    let output = 0n;
                    let dy = 0n;
                    try {
                        const initialCollateralBalance = await inContract.balanceOf(user.address);
                        const initialOutBalance = await outContract.balanceOf(user.address);
                        //@ts-ignore
                        dy = await router.connect(user).get_dy(routeAddresses, swapParamsFull!, amountIn, zapPools);

                        //@ts-ignore
                        await router.connect(user).exchange(routeAddresses!, swapParamsFull!, amountIn, dy - (dy * 10n) / 100n, zapPools, await user.getAddress());

                        const afterCollateralBalance = await inContract.balanceOf(user.address);
                        const afterOutBalance = await outContract.balanceOf(user.address);
                        if (afterCollateralBalance - initialCollateralBalance === 0n || afterOutBalance - initialOutBalance === 0n) {
                            console.log("try", {swap: swapParamsFull.at(0), amountIn, error: "No balance change", output});
                            continue;
                        } else {
                            console.log("✅ Sucess > ", route.display);
                            return {swapType: swapTypes[j], poolType: poolTypes[i], swapParams: currentSwapParams, ...route, coins};
                        }
                    } catch (e: any) {}
                }
            }
        }
        console.log("❌ Error  > ", route.display, "\x1b[38;5;214m No combnaison found \x1b[0m");
        throw new Error(`No valid params found, tested ${testedParamsCount} params`);
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

    _replaceRouteResult = (route: RouteResult, map: Record<string, string>): RouteResult => {
        const replace = (address: string): string => {
            if (map[address]) {
                return map[address];
            }
            return address;
        };

        const newRoute = {
            ...route,
        };
        newRoute.start = replace(route.start);
        newRoute.end = replace(route.end);
        newRoute.params.routeAddresses = route.params.routeAddresses.map((address) => replace(address));
        return newRoute;
    };

    createRouteTemplate = (route: RouteResult[]): RouteResult[] => {
        const map = {} as Record<string, string>;
        Object.entries(liquidationAssets).reduce((_map, [key, value]) => {
            _map[value] = key;
            return _map;
        }, map);
        console.log(map);
        const newRoutes = route.map((route) => this._replaceRouteResult(route, map));
        return newRoutes;
    };

    hydrateRouteTemplate = (route: RouteResult[]): RouteResult[] => {
        const newRoutes = route.map((route) => this._replaceRouteResult(route, liquidationAssets));
        return newRoutes;
    };
}

export const liquidationAssets: Record<string, string> = {
    "sDAI savings": commonERC20.sDAI,
    DAI: commonERC20.DAI,
    sDAI: commonERC20.sDAI,
    USDT: commonERC20.USDT,
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
    FRAXBP: FRAX_USDC_LP,
    /* Pools */
    FRAXUSDe: CRV_LP_FRAX_USDe,
    fraxusdc: CRV_DUO_FRAXBP_POOL,
    "DOLA/USR": CRV_DUO_DOLA_USR,
    "DOLA/FRAXBP": CRV_DUO_DOLA_FRAXBP,
    "crvUSD/fxUSD": CRV_DUO_crvUSD_fxUSD,
    "deUSD/USDC": CRV_DUO_deUSD_USDC,
    "deUSD/DOLA": CRV_DUO_deUSD_DOLA,
    "USDe-USDC": CRV_DUO_USDe_USDC,
    "frxUSD/USDe": CRV_DUO_frxUSD_USDe,
    "FRAX/frxUSD": CRV_DUO_FRAX_frxUSD,
    "USDC/fxUSD": "0x5018be882dcce5e3f2f3b0913ae2096b9b3fb61f",
    "USDC/crvUSD": CRV_DUO_USDC_crvUSD,
    "crvUSD/USDC": CRV_DUO_USDC_crvUSD,
    "USDT/crvUSD": CRV_DUO_USDT_crvUSD,
    "sDAI/sUSDe": "0x167478921b907422f8e88b43c4af2b8bea278d3a",
    "USDC/USDT": CRV_DUO_USDC_USDT, //0x4f493b7de8aac7d55f71853688b1f7c8f0243c85
    "USDT/USDC": CRV_DUO_USDC_USDT, //0x4f493b7de8aac7d55f71853688b1f7c8f0243c85
    "USR/RLP": CRV_DUO_USR_RLP,
    "scrvUSD/sUSDe": CRV_DUO_scrvUSD_sUSDe,
    "USR/USDC": CRV_DUO_USR_USDC,
    "DAI/USDC/USDT": CRV_TRI_DAI_USDC_USDT,
    "scrvUSD savings": commonERC20.scrvUSD,
    "USDC/USDe": CRV_DUO_USDe_USDC,
    "FRAX/USDC": CRV_DUO_FRAXBP_POOL,
    "crvUSD/DOLA": "0x8272E1A3dBef607C04AA6e5BD3a1A134c8ac063B", // 0x8272E1A3dBef607C04AA6e5BD3a1A134c8ac063B
    "crvUSD/FRAX": "0x0CD6f267b2086bea681E922E19D40512511BE538",
    "DOLA/sUSDe": CRV_DUO_DOLA_sUSDe,
    "sDAI/FRAX": "0xcE6431D21E3fb1036CE9973a3312368ED96F5CE7",
    "deUSD/USDT": CRV_DUO_deUSD_USDT,
    "crvUSD/USDT": CRV_DUO_USDT_crvUSD,
    "sUSDS/frxUSD": CRV_DUO_sUSDS_frxUSD,
    "DOLA/sUSDS": CRV_DUO_DOLA_sUSDS,
    "crvUSD/USDe": "0xF55B0f6F2Da5ffDDb104b58a60F2862745960442", // 0xF55B0f6F2Da5ffDDb104b58a60F2862745960442
    "DOLA/scrvUSD": CRV_DUO_DOLA_scrvUSD,
    "scrvUSD/sUSDS": CRV_DUO_scrvUSD_sUSDS,
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
    errors: {route: Transfer; error: string}[];
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

export type RouteResult = {
    route: string;
    start: string;
    end: string;
    params: {
        routeAddresses: string[];
        swapParamsFull: number[][];
    };
};
