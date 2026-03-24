/**
 * Example A - Liquidation with Curve swap route
 *
 * Flow:
 *   1. Find a liquidable position (healthRatio < 1)
 *   2. Deploy CurveLPToUSGRouter
 *   3. Build routerCall: LP → remove_liquidity_one_coin → (optional intermediate→USDC) → USDC → USG
 *   4. Call market.liquidate() with ZapStruct(router, routerCall)
 *
 * Prerequisites:
 *   - Run liquidationSetUp.ts first (creates positions + drops oracle prices)
 *
 * Usage:
 *   npx hardhat run js-scripts/hardhat/liquidation-manual/exampleA_liquidateWithSwap.ts --network localhost
 */
import {ethers, network} from "hardhat";
import {formatEther} from "ethers";
import {loadAddresses} from "../USG/actions/common";
import {
    USDC_ADDRESS,
    KNOWN_USDC_ROUTES,
    DeployedAddresses,
    getCandidateUsers,
    findFirstLiquidablePosition,
    computeUsgNeeded,
    computeSafeLiquidationParams,
    getCurvePoolCoinCount,
    printPosition,
} from "./helpers";

/**
 * Find the best coin index in the LP pool to withdraw for a route to USDC.
 * If USDC is directly in the pool, uses it (no midPool needed).
 * Otherwise uses KNOWN_USDC_ROUTES to find a coin with a known swap to USDC.
 */
async function findWithdrawRoute(collatTokenAddr: string): Promise<{
    withdrawIndex: number;
    withdrawnToken: string;
    midPool: string;
    midFromIndex: number;
    midToIndex: number;
}> {
    const pool = await ethers.getContractAt("ICurveStableSwapNG", collatTokenAddr);
    const nCoins = await getCurvePoolCoinCount(collatTokenAddr);

    // Check if USDC is directly in the pool
    for (let i = 0; i < nCoins; i++) {
        const coinAddr = await pool.coins(i);
        if (coinAddr.toLowerCase() === USDC_ADDRESS.toLowerCase()) {
            return {withdrawIndex: i, withdrawnToken: USDC_ADDRESS, midPool: ethers.ZeroAddress, midFromIndex: 0, midToIndex: 0};
        }
    }

    // Find a coin with a known route to USDC
    for (let i = 0; i < nCoins; i++) {
        const coinAddr = await pool.coins(i);
        const route = KNOWN_USDC_ROUTES[coinAddr];
        if (route) {
            return {withdrawIndex: i, withdrawnToken: coinAddr, midPool: route.pool, midFromIndex: route.fromIndex, midToIndex: route.toIndex};
        }
    }

    // Fallback: use coin 0 (will likely fail at swap)
    const coin0 = await pool.coins(0);
    console.warn(`  ⚠ No known route for LP ${collatTokenAddr}, using coin[0] (${coin0}) as fallback`);
    return {withdrawIndex: 0, withdrawnToken: coin0, midPool: ethers.ZeroAddress, midFromIndex: 0, midToIndex: 0};
}

// ============================================================================
// MAIN
// ============================================================================

async function main() {
    await network.provider.send("evm_setAutomine", [true]);

    const signers = await ethers.getSigners();
    const liquidator = signers[2];
    const liquidatorAddress = await liquidator.getAddress();

    console.log("=== Example A: Liquidation with Curve swap ===\n");
    console.log(`Liquidator: ${liquidatorAddress}`);

    let addresses: DeployedAddresses;
    try {
        addresses = loadAddresses() as DeployedAddresses;
    } catch {
        console.error("addresses.json not found. Run liquidationSetUp.ts first.");
        return;
    }

    const marketViewerAddr = addresses.utilities?.marketViewer;
    const usgAddr = addresses.tokens?.USG;
    const zappingProxyAddr = addresses.utilities?.zappingProxy;

    if (!marketViewerAddr || !usgAddr) {
        console.error("Missing marketViewer or USG address in addresses.json");
        return;
    }
    if (!zappingProxyAddr) {
        console.error("Missing zappingProxy in addresses.json");
        return;
    }

    const marketViewer = await ethers.getContractAt("MarketViewer", marketViewerAddr);
    const usgUsdcPoolAddress = addresses.lps?.["USG-USDC"];
    if (!usgUsdcPoolAddress) {
        console.error("USG-USDC pool not found in addresses.json");
        return;
    }

    const userAddresses = await getCandidateUsers();

    console.log("\n--- Scanning for liquidable positions ---\n");
    const pos = await findFirstLiquidablePosition(addresses, marketViewer, userAddresses);

    if (!pos) {
        console.log("No liquidable positions found. Make sure liquidationSetUp.ts has been run.");
        return;
    }

    printPosition(pos);

    const {collatTokenAddr, fee, usgNeeded} = await computeUsgNeeded(pos.market, pos.collatBalance, pos.userDebt);
    console.log(`  USG needed: ${formatEther(usgNeeded)} (debt ${formatEther(pos.userDebt)} + fee ${formatEther(fee)})`);

    // --- Deploy CurveLPToUSGRouter ---
    console.log("\n  Deploying CurveLPToUSGRouter...");
    const RouterFactory = await ethers.getContractFactory("CurveLPToUSGRouter", liquidator);
    const router = await RouterFactory.deploy();
    await router.waitForDeployment();
    const routerAddress = await router.getAddress();
    console.log(`  CurveLPToUSGRouter deployed at: ${routerAddress}`);

    // --- Build Curve route ---
    const withdrawRoute = await findWithdrawRoute(collatTokenAddr);

    const hasMidPool = withdrawRoute.midPool !== ethers.ZeroAddress;
    console.log(
        hasMidPool
            ? `  Route: LP[${withdrawRoute.withdrawIndex}] → ${withdrawRoute.withdrawnToken} → midPool(${withdrawRoute.midFromIndex}→${withdrawRoute.midToIndex}) → USDC → USG`
            : `  Route: LP[${withdrawRoute.withdrawIndex}] → USDC → USG`
    );

    // Encode the routerCall (struct-based swap)
    const routerInterface = (await ethers.getContractFactory("CurveLPToUSGRouter")).interface;
    const routerCall = routerInterface.encodeFunctionData("swap", [
        {
            lpToken: collatTokenAddr,
            lpAmount: pos.collatBalance,
            withdrawIndex: withdrawRoute.withdrawIndex,
            withdrawnToken: withdrawRoute.withdrawnToken,
            midPool: withdrawRoute.midPool,
            midFromIndex: withdrawRoute.midFromIndex,
            midToIndex: withdrawRoute.midToIndex,
            usdc: USDC_ADDRESS,
            usgPool: usgUsdcPoolAddress,
            usdcIndexInUsgPool: 0,
            usgIndexInUsgPool: 1,
            usg: usgAddr,
            receiver: liquidatorAddress,
        },
    ]);

    // --- Compute safe parameters with slippage protection ---
    const safeParams = computeSafeLiquidationParams(usgNeeded, pos.collatBalance, pos.userDebt, true);

    // --- Approve USG for the market (capped to maxUsgToBurn) ---
    const usg = await ethers.getContractAt("USG", usgAddr);
    await usg.connect(liquidator).approve(pos.marketAddress, safeParams.maxUsgToBurn);

    // --- Execute liquidation ---
    console.log("  Executing liquidation with Curve swap...");
    const tx = await pos.market.connect(liquidator).liquidate(
        {
            account: pos.userAddress,
            postLiquidate: {
                collatAmountToLiquidate: pos.collatBalance,
                minUsgOut: safeParams.minUsgOut,
                maxUsgToBurn: safeParams.maxUsgToBurn,
                minCollatAmountToLiquidate: safeParams.minCollatAmountToLiquidate,
                isReceiptOut: false,
            },
            minCollatValueToLiquidate: safeParams.minCollatValueToLiquidate,
        },
        {router: routerAddress, routerCall}
    );

    const receipt = await tx.wait();
    console.log(`\n  TX: ${receipt?.hash}`);

    const hrAfter = await marketViewer.healthRatio(pos.marketAddress, pos.userAddress);
    const debtAfter = await marketViewer.userDebt(pos.marketAddress, pos.userAddress);
    console.log(`  Post-liquidation: HR=${formatEther(hrAfter)}, Debt=${formatEther(debtAfter)} USG`);
    console.log("  Liquidation with Curve swap successful!");

    console.log("\n=== Done ===");
}

main().catch(console.error);
