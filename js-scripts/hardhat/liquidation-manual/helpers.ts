/**
 * Shared helpers for liquidation-manual scripts.
 */
import {ethers} from "hardhat";
import {formatEther} from "ethers";

// ============================================================================
// CONSTANTS
// ============================================================================

export const USDC_ADDRESS = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
export const AAVE_V3_POOL = "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2";
export const HR_ONE = ethers.parseEther("1");

/** Known Curve routes: coin address → { pool, fromIndex, toIndex } to swap to USDC */
export const KNOWN_USDC_ROUTES: Record<string, {pool: string; fromIndex: number; toIndex: number}> = {
    // crvUSD → USDC via crvUSD/USDC pool
    "0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E": {pool: "0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E", fromIndex: 0, toIndex: 1},
    // USDT → USDC via USDC/USDT pool
    "0xdAC17F958D2ee523a2206206994597C13D831ec7": {pool: "0x3aF987F2f2b7c25EF0018CA0bBE4865D6BCA065d", fromIndex: 1, toIndex: 0},
};

// ============================================================================
// TYPES
// ============================================================================

export interface MarketInfo {
    marketAddress: string;
    collatName: string;
}

export interface DeployedAddresses {
    markets: MarketInfo[];
    utilities: {
        marketViewer: string;
        zappingProxy?: string;
        [key: string]: string | undefined;
    };
    tokens: {
        USG: string;
        [key: string]: string | undefined;
    };
    lps: {
        "USG-USDC"?: string;
        [key: string]: string | undefined;
    };
}

export interface LiquidablePosition {
    market: any;
    marketAddress: string;
    collatName: string;
    userAddress: string;
    hr: bigint;
    collatBalance: bigint;
    userDebt: bigint;
}

// ============================================================================
// HELPERS
// ============================================================================

export async function getCandidateUsers(max = 20): Promise<string[]> {
    const signers = await ethers.getSigners();
    return Promise.all(signers.slice(0, max).map((s) => s.getAddress()));
}

export async function findFirstLiquidablePosition(
    addresses: DeployedAddresses,
    marketViewer: any,
    userAddresses: string[]
): Promise<LiquidablePosition | null> {
    for (const marketInfo of addresses.markets || []) {
        const marketAddress = marketInfo.marketAddress;
        const collatName = marketInfo.collatName;

        const code = await ethers.provider.getCode(marketAddress);
        if (code === "0x") continue;

        const market = await ethers.getContractAt("MarketExternalActions", marketAddress);

        for (const userAddress of userAddresses) {
            try {
                const collatBalance = await market.collateralBalances(userAddress);
                if (collatBalance === 0n) continue;

                const hr = await marketViewer.healthRatio(marketAddress, userAddress);
                if (hr >= HR_ONE) continue;

                const userDebt = await marketViewer.userDebt(marketAddress, userAddress);
                return {market, marketAddress, collatName, userAddress, hr, collatBalance, userDebt};
            } catch {
                continue;
            }
        }
    }
    return null;
}

export async function computeUsgNeeded(market: any, collatAmount: bigint, userDebt: bigint) {
    const oracleAddr = await market.collatOracle();
    const oracle = await ethers.getContractAt("IPriceOracle", oracleAddr);
    const collatPrice = await oracle.latestAnswer(true);
    const collatTokenAddr: string = await market.collatToken();
    const collatToken = await ethers.getContractAt("IERC20Metadata", collatTokenAddr);
    const collatDecimals = await collatToken.decimals();
    const collatValue = (collatPrice * collatAmount) / 10n ** collatDecimals;
    const liqFeeRate = await market.liquidationFee();
    const fee = collatValue > userDebt ? ((collatValue - userDebt) * liqFeeRate) / 100_000n : 0n;
    const usgNeeded = userDebt + fee;
    return {collatTokenAddr, collatToken, fee, usgNeeded};
}

export function printPosition(pos: LiquidablePosition) {
    console.log("Found liquidable position:");
    console.log(`  Market:     ${pos.collatName} (${pos.marketAddress})`);
    console.log(`  User:       ${pos.userAddress}`);
    console.log(`  HR:         ${formatEther(pos.hr)}`);
    console.log(`  Collateral: ${formatEther(pos.collatBalance)}`);
    console.log(`  Debt:       ${formatEther(pos.userDebt)} USG`);
}

export function formatShortAddress(address: string) {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

/**
 * Get the number of coins in a Curve pool.
 * Tries `N_COINS()` first (StableSwapNG), falls back to iterating `coins(i)` until revert.
 */
export async function getCurvePoolCoinCount(poolAddress: string): Promise<number> {
    const pool = await ethers.getContractAt("ICurveStableSwapNG", poolAddress);
    try {
        return Number(await pool.N_COINS());
    } catch {
        // Older pools don't have N_COINS — probe coins(i) until revert
        for (let i = 0; i < 8; i++) {
            try {
                await pool.coins(i);
            } catch {
                return i;
            }
        }
        return 8;
    }
}

/** Default slippage tolerance in basis points (3%) */
export const SLIPPAGE_BPS = 300n;
const BPS_DENOMINATOR = 10_000n;

/**
 * Compute safe liquidation parameters with slippage protection.
 *
 * @param usgNeeded    Expected USG to cover debt + fee
 * @param collatAmount Collateral amount being liquidated
 * @param userDebt     User's outstanding debt
 * @param hasSwap      Whether a swap route is used (true) or direct liquidation (false)
 * @param slippageBps  Slippage tolerance in basis points (default 300 = 3%)
 */
export function computeSafeLiquidationParams(
    usgNeeded: bigint,
    collatAmount: bigint,
    userDebt: bigint,
    hasSwap: boolean,
    slippageBps: bigint = SLIPPAGE_BPS
) {
    const slippageFactor = BPS_DENOMINATOR - slippageBps;
    const bufferFactor = BPS_DENOMINATOR + slippageBps;

    return {
        // Minimum USG expected from the swap (0 if no swap / direct liquidation)
        minUsgOut: hasSwap ? (usgNeeded * slippageFactor) / BPS_DENOMINATOR : 0n,
        // Cap USG burn to expected amount + slippage buffer
        maxUsgToBurn: (usgNeeded * bufferFactor) / BPS_DENOMINATOR,
        // Accept at least 97% of requested collateral
        minCollatAmountToLiquidate: (collatAmount * slippageFactor) / BPS_DENOMINATOR,
        // Collateral value must be at least the user debt (position is underwater)
        minCollatValueToLiquidate: (userDebt * slippageFactor) / BPS_DENOMINATOR,
    };
}
