import {AddressLike, BigNumberish, MaxUint256, ZeroAddress} from "ethers";
import fs from "fs";
import {ethers} from "hardhat";
import path from "path";
import {giveTokenToAddresss} from "../../thief";
import {commonERC20, routers, thiefConfig} from "defi-resources";
import {SignerWithAddress} from "@nomicfoundation/hardhat-ethers/signers";
import {curveLp} from "defi-resources";

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

export const ThiefConfig = [
    ...Object.entries(thiefConfig.THIEF_TOKEN_CONFIG).map(([key, value]) => ({
        token: key,
        address: value.address,
        slot: value.slotBalance,
        isVyper: value.isVyper,
        decimals: value.decimals,
    })),
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
        singleSwaps: path.join(__dirname, "../data", "singleSwaps.json"),
        verifiedRoutes: path.join(__dirname, "../data", "verifiedRoutes.json"),
        finalRoutes: path.join(__dirname, "../data", "finalRoutes.json"),
    };

    loadFile<T>(type: keyof typeof this.PATHS) {
        return JSON.parse(fs.readFileSync(this.PATHS[type], "utf-8")) as T;
    }

    saveFile<T>(type: keyof typeof this.PATHS, data: T) {
        fs.writeFileSync(this.PATHS[type], JSON.stringify(data, null, 2));
    }

    formatSingleSwaps(routes: RouteParams[]): SingleSwap[] {
        const sigleSwaps: SingleSwap[] = [];
        const map = new Map<string, string>();

        routes.map((route) => {
            route.routes?.forEach((r) => {
                const display = `${r.in} >> ${r.pool} >> ${r.out}`;
                if (!map.has(display)) {
                    sigleSwaps.push({
                        in: liquidationAssets[r.in],
                        pool: liquidationAssets[r.pool],
                        out: liquidationAssets[r.out],
                        display: display,
                    });
                }
            });
        });
        return sigleSwaps;
    }

    async getCsv() {
        const sheetId = "1iHxA1src-lwCQjp396I6CCuM1u_catd2pp-EmjrSiT8";
        const gid = "2047399010";
        const url = `https://docs.google.com/spreadsheets/d/${sheetId}/export?format=csv&gid=${gid}`;
        try {
            const response = await fetch(url);
            if (!response.ok) {
                throw new Error(`Erreur HTTP: ${response.status}`);
            }
            return await response.text();
        } catch (error) {
            return fs.readFileSync(this.CSV_PATH, "utf8");
        }
    }

    async validateCsv() {
        const names = new Set<string>();
        const csvData = await this.getCsv();

        const rows = csvData.split("\r").map((row: string) => row.split(","));

        const formattedCsv: string[][] = [];

        for (let i = 1; i < rows.length; i++) {
            const row = rows[i];

            row[0] = row[0].replace("\n", "");
            for (let j = 0; j < row.length; j++) {
                const cell = row[j].trim();
                names.add(cell);
                // Remove empty cells
                if (cell === "") {
                    formattedCsv.push(row.slice(0, j));
                    break;
                }
            }
        }

        names.forEach((name) => {
            if (!liquidationAssets[name]) {
                this.missing.symbols.add(name);
            }
        });
        return {csv: formattedCsv, valid: (this.missing?.symbols?.size || 0) === 0, missing: this.missing.symbols};
    }

    loadRoutesFromCSV(csvData: string[][]): RouteParams[] {
        const routes: RouteParams[] = [];

        csvData.forEach((row) => {
            const tokenIn = row[0];
            const tokenOut = row[row.length - 1];
            const routeSteps = [];

            for (let i = 0; i < row.length - 1; ) {
                routeSteps.push({
                    in: row[i],
                    pool: row[i + 1],
                    out: row[i + 2],
                });
                i += 2;
            }

            routes.push({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                routes: routeSteps,
            });
        });

        console.log(routes.length, ' routes found &  processed in the CSV file "this.routeData" setted');
        this.routeData = routes;
        return routes;
    }

    // test routes with all the step
    async testRoute(verifiedRoutes: VerifiedRoutes, transfers: SingleSwap[][]) {
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

    async testRouteSteps(singleSwaps: SingleSwap[]): Promise<VerifiedRoutes> {
        const pools = new Map<string, SingleSwap>();
        const params: VerifiedRoute[] = [];
        const errors: {route: SingleSwap; error: string}[] = [];

        // Extract pools and their respective input/output tokens
        singleSwaps.forEach((singleSwap) => {
            pools.set(singleSwap.display, singleSwap);
        });

        // const thiefData = ThiefConfig.reverse().find((token) => token.address.toLowerCase() === route.in.toLowerCase());
        const thiefData = ThiefConfig.reverse();

        let coins: string[] = [];
        for (const [_, route] of pools.entries()) {
            try {
                coins = ["noONe"];
                // No more RPC call; we use tokenIn & tokenOut from JSON
                const {coins: _coins} = await this._getPoolInfo(route.pool);
                coins = _coins;
                const result = await this._determineSwapParams(route.pool, route, thiefData, _coins);
                params.push({route, result: {coins: result.coins, swapParams: result.swapParams}});
            } catch (error: any) {
                errors.push({error: error.message, route});
            }
        }
        return {params, errors};
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

    async prepareUserForExchange(
        route: SingleSwap,
        user: SignerWithAddress,
        amount: number,
        thiefConfig:
            | {
                  token: string;
                  address: string;
                  slot: number;
                  isVyper: boolean;
                  decimals: number;
              }
            | undefined
    ) {
        const isTgAsset = route.display.split(">>")[0].trim().endsWith("*");
        const tokenInContract = await ethers.getContractAt("IERC20Metadata", route.in);
        let initialInBalance = await tokenInContract.balanceOf(user.address);
        const amountIn = ethers.parseUnits(amount.toString(), thiefConfig?.decimals || 18);
        if (thiefConfig || isTgAsset) {
            if (initialInBalance < amountIn) {
                await giveTokenToAddresss(user, route.in, amountIn, thiefConfig?.slot || 0, !!thiefConfig ? thiefConfig.isVyper : !isTgAsset);
                initialInBalance = await tokenInContract.balanceOf(user.address);
            }
        } else {
            throw Error(`Thief config for ${route.in} not found`);
        }

        const txApprove0 = await tokenInContract.connect(user).approve(routerAddress, 0);
        await txApprove0.wait();

        const txApproveMax = await tokenInContract.connect(user).approve(routerAddress, MaxUint256);
        await txApproveMax.wait();

        const allowance = await tokenInContract.allowance(user.address, routerAddress);
        if (allowance < amountIn) {
            throw Error(`No allowance for  ${route.display}`);
        }
    }

    async _determineSwapParams(
        poolAddress: AddressLike,
        route: SingleSwap,
        thiefData: {
            token: string;
            address: string;
            slot: number;
            isVyper: boolean;
            decimals: number;
        }[],
        coins: string[]
    ) {
        const thiefConfig = thiefData.find((token) => token.address.toLowerCase() === route.in.toLowerCase());
        const zapPools: AddressLike[] = [ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress];
        const [, , , , , , , , user] = await ethers.getSigners();
        const router = await ethers.getContractAt("ICurveRouter", routerAddress);
        const routeAddresses: AddressLike[] = [route.in, poolAddress, route.out, ...Array(8).fill(ZeroAddress)];
        const ZEROS = [0, 0, 0, 0, 0];
        const swapTypes = [1, 2, 3, 4, 5, 6, 7, 8, 9];
        const poolTypes = [1, 2, 3, 4, 10, 20, 30];

        const amount = "10";
        const tokenInContract = await ethers.getContractAt("IERC20Metadata", route.in);
        const amountIn = ethers.parseUnits(amount, thiefConfig?.decimals || 18);

        try {
            await this.prepareUserForExchange(route, user, 10, thiefConfig);
        } catch (e: any) {
            console.log("❌ Error  > ", route.display, "\x1b[38;5;214m " + e.message + "\x1b[0m");
            throw new Error(e.message);
        }

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
                    const currentSwapParams = [inIndex, outIndex, swapTypes[j], poolTypes[i], coins.length === 1 ? 0 : coins.length];
                    console.log(currentSwapParams);
                    testedParamsCount++;
                    const swapParamsFull = [currentSwapParams, ZEROS, ZEROS, ZEROS, ZEROS];
                    let output = 0n;
                    let dy = 0n;
                    try {
                        const initialCollateralBalance = await tokenInContract.balanceOf(user.address);
                        const initialOutBalance = await outContract.balanceOf(user.address);

                        //@ts-ignore
                        dy = await router.connect(user).get_dy(routeAddresses, swapParamsFull, amountIn, zapPools);

                        //@ts-ignore
                        await router.connect(user).exchange(routeAddresses!, swapParamsFull!, amountIn, dy - (dy * 10n) / 100n, zapPools, await user.getAddress());

                        const afterCollateralBalance = await tokenInContract.balanceOf(user.address);
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
        console.log("❌ Error  > ", route.display, "\x1b[38;5;214m No combination found \x1b[0m");
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
    fxUSD: commonERC20.fxUSD,
    GHO: commonERC20.GHO,
    stETH: commonERC20.stETH,
    ETH: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
    WBTC: commonERC20.WBTC,

    FRAXBP: curveLp.FRAX_USDC_LP,
    /* Pools */
    FRAXUSDe: curveLp.CRV_LP_FRAX_USDe,
    fraxusdc: curveLp.CRV_DUO_FRAXBP_POOL,
    "DOLA/USR": curveLp.CRV_DUO_DOLA_USR,
    "DOLA/FRAXBP": curveLp.CRV_DUO_DOLA_FRAXBP,
    "crvUSD/fxUSD": curveLp.CRV_DUO_crvUSD_fxUSD,
    "deUSD/USDC": curveLp.CRV_DUO_deUSD_USDC,
    "deUSD/DOLA": curveLp.CRV_DUO_deUSD_DOLA,
    "USDe-USDC": curveLp.CRV_DUO_USDe_USDC,
    "frxUSD/USDe": curveLp.CRV_DUO_frxUSD_USDe,
    "FRAX/frxUSD": curveLp.CRV_DUO_FRAX_frxUSD,
    "USDC/fxUSD": curveLp.CRV_LP_USDC_fxUSD,
    "USDC/crvUSD": curveLp.CRV_DUO_USDC_crvUSD,
    "crvUSD/USDC": curveLp.CRV_DUO_USDC_crvUSD,
    "USDT/crvUSD": curveLp.CRV_DUO_USDT_crvUSD,
    "sDAI/sUSDe": curveLp.CRV_DUO_sDAI_sUSDe,
    "USDC/USDT": curveLp.CRV_DUO_USDC_USDT, //0x4f493b7de8aac7d55f71853688b1f7c8f0243c85
    "USR/RLP": curveLp.CRV_DUO_USR_RLP,
    "scrvUSD/sUSDe": curveLp.CRV_DUO_scrvUSD_sUSDe,
    "USR/USDC": curveLp.CRV_DUO_USR_USDC,
    "DAI/USDC/USDT": curveLp.CRV_TRI_DAI_USDC_USDT,
    "scrvUSD savings": commonERC20.scrvUSD,
    "USDC/USDe": curveLp.CRV_DUO_USDe_USDC,
    "FRAX/USDC": curveLp.CRV_DUO_FRAXBP_POOL,
    "crvUSD/DOLA": curveLp.CRV_DUO_DOLA_crvUSD, // 0x8272E1A3dBef607C04AA6e5BD3a1A134c8ac063B
    "crvUSD/FRAX": curveLp.CRV_DUO_crvUSD_FRAX,
    "DOLA/sUSDe": curveLp.CRV_DUO_DOLA_sUSDe,
    "sDAI/FRAX": curveLp.CRV_LP_FRAX_sDAI,
    "deUSD/USDT": curveLp.CRV_DUO_deUSD_USDT,
    "crvUSD/USDT": curveLp.CRV_DUO_USDT_crvUSD,
    "sUSDS/frxUSD": curveLp.CRV_DUO_sUSDS_frxUSD,
    "DOLA/sUSDS": curveLp.CRV_DUO_DOLA_sUSDS,
    "crvUSD/USDe": "0xF55B0f6F2Da5ffDDb104b58a60F2862745960442",
    "DOLA/scrvUSD": curveLp.CRV_DUO_DOLA_scrvUSD,
    "scrvUSD/sUSDS": curveLp.CRV_DUO_scrvUSD_sUSDS,
    "WBTC/ETH/USDC": curveLp.CRV_TRI_CRYPTO_USDC,
    "WBTC/cbBTC": curveLp.CRV_DUO_cbBTC_WBTC,
    "stETH/ETH": curveLp.CRV_DUO_stETH_ETH,
    "GHO/fxUSD": curveLp.CRV_DUO_GHO_fxUSD,
    "GHO/USR": curveLp.CRV_DUO_GHO_USR,
    "GHO/crvUSD": curveLp.CRV_DUO_GHO_crvUSD,
    "GHO/USDe": curveLp.CRV_DUO_GHO_USDe,
    "pxETH/stETH": curveLp.CRV_DUO_pxETH_stETH,
};

export type LiquidationAsset = keyof typeof liquidationAssets;

export type RouteParams = {
    tokenIn: LiquidationAsset;
    tokenOut: LiquidationAsset;
    routes: {in: LiquidationAsset; pool: LiquidationAsset; out: LiquidationAsset}[];
};

export type PoolCurveData = {
    id: string;
    address: AddressLike;
    coinsAddresses: [AddressLike, AddressLike];
    registryId: string;
    symbol: string;
    in?: AddressLike;
    out?: AddressLike;
    inIndex: number;
    outIndex: number;
};

type AbiRow = {name: string; type: string; outputs: any[]};
type MissingData = {
    symbols: Set<String>;
};

export interface SingleSwap {
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
    route: SingleSwap;
    result: VerifiedRouteParams;
};

export type VerifiedRoutes = {
    params: VerifiedRoute[];
    errors: {route: SingleSwap; error: string}[];
};

type FinalRouteParams = {
    routeAddresses: string[];
    swapParamsFull: number[][];
};

type FinalRouteResult = {
    route: SingleSwap[];
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
