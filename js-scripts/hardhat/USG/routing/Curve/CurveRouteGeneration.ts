import { AddressLike, MaxUint256, ZeroAddress } from "ethers";
import fs from "fs";
import { ethers } from "hardhat";
import path from "path";
import { giveTokenToAddresss } from "../../../thief/thief";
import { commonERC20, routers, thiefConfig, curveLp, PendlePools } from "@tangent/defi-resources";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

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

export const ThiefConfig = [
    ...Object.entries(thiefConfig.THIEF_TOKEN_CONFIG).map(([key, value]) => ({
        token: key,
        address: value.address,
        slot: value.slotBalance,
        isVyper: value.isVyper,
        decimals: value.decimals,
    })),
];

export class CurveRouteGeneration {
    routeData?: RouteParams[];
    PATHS = {
        rawRoutes: path.join(__dirname, "./data", "rawRoutes.json"),
        singleSwaps: path.join(__dirname, "./data", "singleSwaps.json"),
        finalRoutes: path.join(__dirname, "./data", "finalRoutes.json"),
        finalRoutesTestRepport: path.join(__dirname, "./data", "finalRoutesTestRepport.json"),
    };

    loadFile<T>(type: keyof typeof this.PATHS) {
        return JSON.parse(fs.readFileSync(this.PATHS[type], "utf-8")) as T;
    }

    saveFile<T>(type: keyof typeof this.PATHS, data: T) {
        fs.writeFileSync(this.PATHS[type], JSON.stringify(data));
    }

    async loadDynamicAssets(addressesData: { lps: Record<string, string>; wStables: Record<string, string>; tokens: { USG: string; TAN: string } }) {
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
            liquidationAssets["USG*"] = addressesData.tokens.USG;
            liquidationAssets["TAN*"] = addressesData.tokens.TAN;

            console.log("Dynamic assets loaded successfully");
        } catch (error) {
            console.error("Error loading dynamic assets:", error);
            throw error;
        }
    }

    async getCsv() {
        const sheetId = "1iHxA1src-lwCQjp396I6CCuM1u_catd2pp-EmjrSiT8";
        const gid = "2047399010";
        const url = `https://docs.google.com/spreadsheets/d/${sheetId}/export?format=csv&gid=${gid}`;

        const response = await fetch(url);
        if (!response.ok) {
            throw new Error(`Erreur HTTP: ${response.status}`);
        }
        return await response.text();
    }

    async validateCsv() {
        const names = new Set<string>();
        const missings = new Set<string>();
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
            if (name !== "" && !liquidationAssets[name]) {
                missings.add(name);
            }
        });

        return { csv: formattedCsv, valid: (missings.size || 0) === 0, missing: missings };
    }

    loadRoutesFromCSV(csvData: string[][]): RouteParams[] {
        const routes: RouteParams[] = [];

        // Iterate over rows.
        csvData.forEach((row) => {
            // Generates routes in the normal order of the CSV for Liquidations
            routes.push(this._formatRoutesFromCSV(row));
            // And now reverse order for Leverage
            routes.push(this._formatRoutesFromCSV(row.reverse()));
        });

        return routes;
    }

    _formatRoutesFromCSV(row: string[]): RouteParams {
        const routeSteps = [];
        let display = "";

        // Iterate over Row and cell from A to Z
        for (let i = 0; i < row.length - 1;) {
            const tokenIn = row[i];
            const pool = row[i + 1];
            const out = row[i + 2];

            if (i === 0) {
                display += tokenIn + " >> " + pool + " >> " + out + " >> ";
            } else {
                display += pool + " >> " + out + " >> ";
            }
            routeSteps.push({
                in: tokenIn,
                pool: pool,
                out: out,
            });
            i += 2;
        }

        // Remove the last >>
        display = display.slice(0, display.length - 4);

        return {
            display,
            in: row[0],
            out: row[row.length - 1],
            singleSwaps: routeSteps,
        };
    }

    formatSingleSwaps(routes: RouteParams[]): SingleSwap[] {
        const singleSwaps: SingleSwap[] = [];
        const map = new Map<string, boolean>();

        routes.forEach((route) => {
            route.singleSwaps?.forEach((singleSwap) => {
                const display = `${singleSwap.in} >> ${singleSwap.pool} >> ${singleSwap.out}`;
                if (!map.has(display)) {
                    singleSwaps.push({
                        in: liquidationAssets[singleSwap.in],
                        pool: liquidationAssets[singleSwap.pool],
                        out: liquidationAssets[singleSwap.out],
                        display: display,
                    });
                    map.set(display, true);
                }
            });
        });

        return singleSwaps;
    }

    async testRouteSteps(singleSwaps: SingleSwap[]): Promise<SingleSwapProcessResult> {
        const pools = new Map<string, SingleSwap>();
        const params: VerifiedSingleSwap[] = [];
        const errors: { route: SingleSwap; error: string }[] = [];

        // Extract pools and their respective input/output tokens
        singleSwaps.forEach((singleSwap) => {
            pools.set(singleSwap.display, singleSwap);
        });

        let coins: string[] = [];
        for (const [_, route] of pools.entries()) {
            const thiefData = ThiefConfig.find((token) => token.address.toLowerCase() === route.in.toLowerCase());
            try {
                coins = ["noONe"];
                // No more RPC call; we use tokenIn & tokenOut from JSON
                if (separatedCurvePoolToken[route.pool]) {
                    route.pool = separatedCurvePoolToken[route.pool];
                }
                const { coins: _coins } = await this._getPoolInfo(route.pool);
                coins = _coins;
                const result = await this._determineSwapParams(route.pool, route, thiefData, _coins);
                params.push({ route, result: { coins: result.coins, swapParams: result.swapParams } });
            } catch (error: any) {
                errors.push({ error: error.message, route });
            }
        }
        return { success: params, errors };
    }

    async _getPoolInfo(poolAddress: AddressLike): Promise<{ coins: string[]; lp: string; symbol: string }> {
        const poolAbi = ["function coins(uint256) external view returns (address)", "function symbol() external view returns (string memory)"];

        const poolContract = await ethers.getContractAt(poolAbi, poolAddress as string);
        let symbol = "";
        try {
            symbol = await poolContract.symbol();
        } catch (e) { }
        const coinCount = 4;
        const coins: string[] = [];

        for (let i = 0; i < coinCount; i++) {
            try {
                const coinAddress = await poolContract.coins(i);
                coins.push(coinAddress);
            } catch { }
        }
        let lp = "";

        return { coins, lp, symbol };
    }

    async prepareUserForExchange(
        tokenIn: string,
        display: string,
        user: SignerWithAddress,
        amount: string,
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
        const isTgAsset = display.split(">>")[0].trim().endsWith("*");
        const isETH = tokenIn === "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
        const tokenInContract = await ethers.getContractAt("IERC20Metadata", tokenIn);

        let initialInBalance = isETH ? await ethers.provider.getBalance(user.address) : await tokenInContract.balanceOf(user.address);
        const amountIn = ethers.parseUnits(amount, thiefConfig?.decimals || 18);

        if (thiefConfig || isTgAsset) {
            if (initialInBalance < amountIn) {
                await giveTokenToAddresss(user, tokenIn, amountIn, thiefConfig?.slot || 0, !!thiefConfig ? thiefConfig.isVyper : !isTgAsset);
                initialInBalance = await tokenInContract.balanceOf(user.address);
            }
        } else if (isETH) {
            // initialInBalance = await tokenInContract.balanceOf(user.address);
        } else {
            throw Error(`Thief config for ${tokenIn} not found`);
        }

        if (!isETH) {
            const txApprove0 = await tokenInContract.connect(user).approve(routers.CURVE_V1_2_ROUTER, 0);
            await txApprove0.wait();

            const txApproveMax = await tokenInContract.connect(user).approve(routers.CURVE_V1_2_ROUTER, MaxUint256);
            await txApproveMax.wait();
        }
    }

    async _determineSwapParams(
        poolAddress: AddressLike,
        route: SingleSwap,
        thiefData:
            | {
                token: string;
                address: string;
                slot: number;
                isVyper: boolean;
                decimals: number;
            }
            | undefined,
        coins: string[]
    ) {
        const isInETH = route.in === liquidationAssets.ETH;
        const isOutETH = route.out === liquidationAssets.ETH;

        const zapPools: AddressLike[] = [ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress, ZeroAddress];
        const [, , , , , , , , user] = await ethers.getSigners();
        const router = await ethers.getContractAt("ICurveRouter", routers.CURVE_V1_2_ROUTER);
        const routeAddresses: AddressLike[] = [route.in, poolAddress, route.out, ...Array(8).fill(ZeroAddress)];
        const ZEROS = [0, 0, 0, 0, 0];
        const swapTypes = [1, 4, 6, 8, 9];
        const poolTypes = [1, 2, 3, 10, 20, 30];

        const amount = "1";

        const tokenInContract = await ethers.getContractAt("IERC20Metadata", route.in);
        const amountIn = ethers.parseUnits(amount, thiefData?.decimals || 18);

        try {
            await this.prepareUserForExchange(route.in, route.display, user, amount, thiefData);
        } catch (e: any) {
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
        let deltaInBalance = isInETH ? await ethers.provider.getBalance(user.address) : await tokenInContract.balanceOf(user.address);
        let deltaOutBalance = isOutETH ? await ethers.provider.getBalance(user.address) : await outContract.balanceOf(user.address);

        let testedParamsCount = 0;
        for (let i = 0; i < poolTypes.length; i++) {
            for (let j = 0; j < swapTypes.length; j++) {
                for (let k = 0; k < indexPossibilities.length; k++) {
                    const [inIndex, outIndex] = indexPossibilities[k];
                    const currentSwapParams = [inIndex, outIndex, swapTypes[j], poolTypes[i], coins.length === 1 ? 0 : coins.length];
                    testedParamsCount++;
                    const swapParamsFull = [currentSwapParams, ZEROS, ZEROS, ZEROS, ZEROS];
                    let output = 0n;
                    let dy = 0n;
                    try {
                        //@ts-ignore
                        dy = await router.connect(user).get_dy(routeAddresses, swapParamsFull, amountIn, zapPools);

                        if (isInETH) {
                            //@ts-ignore
                            await router.connect(user).exchange(routeAddresses!, swapParamsFull!, amountIn, dy - (dy * 1n) / 1000n, zapPools, user.address, { value: amountIn });
                        } else {
                            //@ts-ignore
                            await router.connect(user).exchange(routeAddresses!, swapParamsFull!, amountIn, dy - (dy * 1n) / 1000n, zapPools, user.address);
                        }

                        deltaInBalance = deltaInBalance - (isInETH ? await ethers.provider.getBalance(user.address) : await tokenInContract.balanceOf(user.address));
                        deltaOutBalance = (isOutETH ? await ethers.provider.getBalance(user.address) : await outContract.balanceOf(user.address)) - deltaOutBalance;

                        if (deltaInBalance === 0n || deltaOutBalance === 0n) {
                            console.log("try", { swap: swapParamsFull.at(0), amountIn, error: "No balance change", output });
                            continue;
                        } else {
                            return { swapType: swapTypes[j], poolType: poolTypes[i], swapParams: currentSwapParams, ...route, coins };
                        }
                    } catch (e: any) { }
                }
            }
        }

        throw new Error(`No valid params found, tested ${testedParamsCount} params`);
    }

    hydrateRawRoutes = (routes: RouteParams[], verifiedSingleSwaps: VerifiedSingleSwap[]) => {
        const finalHydratedRoutes: RouteResult = {};
        const errors: string[] = [];
        routes.forEach((route) => {
            const routeAddresses: string[] = [];
            const swapParamsFull = [];
            let finalDisplay = "";
            for (let i = 0; i < route.singleSwaps.length; i++) {
                const routeString = route.singleSwaps[i];
                const singleSwapDisplay = routeString.in + " >> " + routeString.pool + " >> " + routeString.out;
                const singleSwap = verifiedSingleSwaps.find((s) => s.route.display === singleSwapDisplay);

                // We can hydrate only if the single swap test has been found previously
                if (singleSwap) {
                    if (i === 0) {
                        finalDisplay = `${singleSwapDisplay} >> `;

                        routeAddresses.push(singleSwap?.route.in);
                        routeAddresses.push(singleSwap?.route.pool);
                        routeAddresses.push(singleSwap?.route.out);
                    } else {
                        finalDisplay += `${routeString.pool} >> ${routeString.out} >> `;

                        routeAddresses.push(singleSwap?.route?.pool);
                        routeAddresses.push(singleSwap?.route?.out);
                    }
                    swapParamsFull.push(singleSwap.result.swapParams);
                }
                // If we didn't find a corresponding single swap, we stop the loop
                else {
                    finalDisplay = "";
                    break;
                }
            }

            if (finalDisplay === "") {
                errors.push(route.display);
            } else {
                // Remove the last >>
                finalDisplay = finalDisplay.slice(0, finalDisplay.length - 4);

                while (routeAddresses.length < 11) {
                    routeAddresses.push(ZeroAddress);
                }
                while (swapParamsFull.length < 5) {
                    swapParamsFull.push([0, 0, 0, 0, 0]);
                }

                const tokenInAddress = liquidationAssets[route.in].toLocaleLowerCase();
                const tokenOutAddress = liquidationAssets[route.out].toLocaleLowerCase();

                const paramsAndDisplay = {
                    params: {
                        routeAddresses: routeAddresses,
                        swapParamsFull: swapParamsFull,
                    },
                    display: finalDisplay,
                };

                if (finalHydratedRoutes[tokenInAddress]) {
                    if (finalHydratedRoutes[tokenInAddress][tokenOutAddress]) {
                        finalHydratedRoutes[tokenInAddress][tokenOutAddress].push(paramsAndDisplay);
                    } else {
                        finalHydratedRoutes[tokenInAddress][tokenOutAddress] = [paramsAndDisplay];
                    }
                } else {
                    finalHydratedRoutes[tokenInAddress] = { [tokenOutAddress]: [paramsAndDisplay] };
                }
            }
        });
        return { success: finalHydratedRoutes, errors };
    };
}

// Link Pools and tokens that are not the same contract
export const separatedCurvePoolToken: { [lpToken: string]: string } = {
    [curveLp.FRAX_USDC_LP]: curveLp.CRV_DUO_FRAXBP_POOL,
    [curveLp.CRV_DUO_stETH_ETH]: "0xDC24316b9AE028F1497c275EB9192a3Ea0f67022",
};

export const liquidationAssets: Record<string, string> = {
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
    WETH: commonERC20.WETH,
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
    "frxETH/WETH": curveLp.CRV_LP_WETH_frxETH,
    "pxETH/WETH": curveLp.CRV_LP_pxETH_WETH,
};

export type LiquidationAsset = keyof typeof liquidationAssets;

export type RouteParams = {
    display: string;
    in: LiquidationAsset;
    out: LiquidationAsset;
    singleSwaps: { in: LiquidationAsset; pool: LiquidationAsset; out: LiquidationAsset }[];
};

export interface SingleSwap {
    in: string;
    pool: string;
    out: string;
    display: string;
}

type ResultRouteParams = {
    swapParams: number[];
    coins: string[];
};

type VerifiedSingleSwap = {
    route: SingleSwap;
    result: ResultRouteParams;
};

export type SingleSwapProcessResult = {
    success: VerifiedSingleSwap[];
    errors: { route: SingleSwap; error: string }[];
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
    [tokenIn: string]: {
        [tokenOut: string]: SwapParamsAndDisplay[];
    };
};

export type SwapParamsAndDisplay = {
    display: string;
    params: {
        routeAddresses: string[];
        swapParamsFull: number[][];
    };
};
