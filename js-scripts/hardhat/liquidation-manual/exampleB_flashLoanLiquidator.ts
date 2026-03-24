/**
 * Example B - Flash Loan Liquidation via Aave V3
 *
 * Demonstrates the full flash-loan liquidation flow:
 *   1. Deploy FlashLoanLiquidator contract
 *   2. Flash-borrow USDC from Aave V3
 *   3. Swap USDC -> USG via Curve USG-USDC pool
 *   4. Liquidate the position (collateral LP sent to contract)
 *   5. remove_liquidity_one_coin on collateral LP pool → intermediate
 *   6. (Optional) exchange intermediate → USDC on second Curve pool
 *   7. Repay Aave + keep profit
 *
 * Prerequisites:
 *   - Run liquidationSetUp.ts first (creates positions + drops oracle prices)
 *
 * Usage:
 *   npx hardhat run js-scripts/hardhat/liquidation-manual/exampleB_flashLoanLiquidator.ts --network localhost
 */
import {ethers, network} from "hardhat";
import {formatEther, formatUnits} from "ethers";
import {loadAddresses} from "../USG/actions/common";
import {setBalance} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import {
    AAVE_V3_POOL,
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

// ============================================================================
// HELPERS
// ============================================================================

/**
 * Build the Curve route for collateral LP → USDC.
 *
 * Strategy:
 *   - The collateral is a Curve StableSwapNG LP token (pool == LP).
 *   - Query pool.coins(i) to find USDC. If found → remove_liquidity_one_coin to USDC directly.
 *   - If USDC not in pool, withdraw coin[0] and swap it to USDC via a known intermediate pool.
 */
async function buildCurveRoute(collatTokenAddr: string): Promise<{
    withdrawCoinIndex: number;
    swapPool: string;
    swapTokenIn: string;
    swapFromIndex: number;
    swapToIndex: number;
}> {
    const pool = await ethers.getContractAt("ICurveStableSwapNG", collatTokenAddr);
    const nCoins = await getCurvePoolCoinCount(collatTokenAddr);

    // Check if USDC is directly in the pool
    for (let i = 0; i < nCoins; i++) {
        const coinAddr = await pool.coins(i);
        if (coinAddr.toLowerCase() === USDC_ADDRESS.toLowerCase()) {
            return {withdrawCoinIndex: i, swapPool: ethers.ZeroAddress, swapTokenIn: ethers.ZeroAddress, swapFromIndex: 0, swapToIndex: 0};
        }
    }

    // Prefer coins that have a known route to USDC
    for (let i = 0; i < nCoins; i++) {
        const coinAddr = await pool.coins(i);
        const route = KNOWN_USDC_ROUTES[coinAddr];
        if (route) {
            return {withdrawCoinIndex: i, swapPool: route.pool, swapTokenIn: coinAddr, swapFromIndex: route.fromIndex, swapToIndex: route.toIndex};
        }
    }

    // Fallback: withdraw coin 0 and hope for the best (will fail at repay if not profitable)
    console.warn(`  ⚠ No known Curve route for collateral LP ${collatTokenAddr}, using coin[0] fallback`);
    const coin0 = await pool.coins(0);
    return {withdrawCoinIndex: 0, swapPool: ethers.ZeroAddress, swapTokenIn: coin0, swapFromIndex: 0, swapToIndex: 0};
}

// ============================================================================
// MAIN
// ============================================================================

async function main() {
    await network.provider.send("evm_setAutomine", [true]);

    const signers = await ethers.getSigners();
    const deployer = signers[4]; // Use a signer not used as position holder
    const deployerAddress = await deployer.getAddress();
    await setBalance(deployerAddress, ethers.parseEther("100"));

    console.log("=== Example B: Flash Loan Liquidation via Aave V3 ===\n");
    console.log(`Deployer/Owner: ${deployerAddress}`);

    // --- Load deployed contracts ---
    let addresses: DeployedAddresses;
    try {
        addresses = loadAddresses() as DeployedAddresses;
    } catch {
        console.error("addresses.json not found. Run liquidationSetUp.ts first.");
        return;
    }

    const marketViewerAddr = addresses.utilities?.marketViewer;
    const usgAddr = addresses.tokens?.USG;
    if (!marketViewerAddr || !usgAddr) {
        console.error("Missing marketViewer or USG in addresses.json");
        return;
    }

    const marketViewer = await ethers.getContractAt("MarketViewer", marketViewerAddr);
    const usdc = await ethers.getContractAt("IERC20Metadata", USDC_ADDRESS);

    // --- Get USG-USDC pool address ---
    const usgUsdcPoolAddress = addresses.lps?.["USG-USDC"];
    if (!usgUsdcPoolAddress) {
        console.error("USG-USDC pool not found in addresses.json");
        return;
    }
    console.log(`USG-USDC Pool: ${usgUsdcPoolAddress}`);

    // --- Deploy FlashLoanLiquidator ---
    console.log("\nDeploying FlashLoanLiquidator...");
    const FlashLoanLiquidatorFactory = await ethers.getContractFactory("FlashLoanLiquidator", deployer);
    const liquidatorDeploy = await FlashLoanLiquidatorFactory.deploy(AAVE_V3_POOL, USDC_ADDRESS, deployerAddress);
    await liquidatorDeploy.waitForDeployment();
    const liquidatorAddress = await liquidatorDeploy.getAddress();
    const liquidatorContract = await ethers.getContractAt("FlashLoanLiquidator", liquidatorAddress);
    console.log(`FlashLoanLiquidator deployed at: ${liquidatorAddress}`);

    console.log("\n--- Scanning for liquidable positions ---\n");
    const userAddresses = await getCandidateUsers();
    const pos = await findFirstLiquidablePosition(addresses, marketViewer, userAddresses);

    if (!pos) {
        console.log("No liquidable positions found. Make sure liquidationSetUp.ts has been run.");
        console.log("\n=== Done ===");
        return;
    }

    printPosition(pos);

    const {collatTokenAddr, collatToken, fee, usgNeeded} = await computeUsgNeeded(pos.market, pos.collatBalance, pos.userDebt);
    console.log(`  USG needed: ${formatEther(usgNeeded)} (debt ${formatEther(pos.userDebt)} + fee ${formatEther(fee)})`);

    // Flash amount based on usgNeeded with a 5% buffer
    const usdcFlashAmount = ((usgNeeded / 10n ** 12n) * 105n) / 100n;
    console.log(`  USDC flash:  ${formatUnits(usdcFlashAmount, 6)}`);

    // --- Build Curve route for collateral LP → USDC ---
    console.log("  Building Curve route for collateral → USDC...");
    const curveRoute = await buildCurveRoute(collatTokenAddr);
    console.log(`  Withdraw coin index: ${curveRoute.withdrawCoinIndex}, swap pool: ${curveRoute.swapPool === ethers.ZeroAddress ? "none (direct USDC)" : curveRoute.swapPool}`);

    const safeParams = computeSafeLiquidationParams(usgNeeded, pos.collatBalance, pos.userDebt, true);

    const params = {
        market: pos.marketAddress,
        account: pos.userAddress,
        collatAmount: pos.collatBalance,
        maxUsgToBurn: safeParams.maxUsgToBurn,
        usg: usgAddr,
        usgUsdcPool: usgUsdcPoolAddress,
        usdcIndexInPool: 0,
        usgIndexInPool: 1,
        minUsgFromSwap: safeParams.minUsgOut,
        collatToken: collatTokenAddr,
        withdrawCoinIndex: curveRoute.withdrawCoinIndex,
        swapPool: curveRoute.swapPool,
        swapTokenIn: curveRoute.swapTokenIn,
        swapFromIndex: curveRoute.swapFromIndex,
        swapToIndex: curveRoute.swapToIndex,
    };

    console.log("  Executing flash loan liquidation...");
    const tx = await liquidatorContract.connect(deployer).liquidate(usdcFlashAmount, params);
    const receipt = await tx.wait();

    console.log(`\n  TX: ${receipt?.hash}`);

    const collatInContract = await collatToken.balanceOf(liquidatorAddress);
    const usdcInContract = await usdc.balanceOf(liquidatorAddress);
    console.log(`  Collateral remaining in contract: ${formatEther(collatInContract)}`);
    console.log(`  USDC profit in contract: ${formatUnits(usdcInContract, 6)}`);

    const debtAfter = await marketViewer.userDebt(pos.marketAddress, pos.userAddress);
    console.log(`  Remaining debt: ${formatEther(debtAfter)} USG`);
    console.log("  Liquidation successful!\n");

    if (usdcInContract > 0n) {
        console.log("  Withdrawing USDC profit to deployer...");
        await liquidatorContract.connect(deployer).withdrawTokens(USDC_ADDRESS, deployerAddress, usdcInContract);
        console.log(`  Withdrew ${formatUnits(usdcInContract, 6)} USDC`);
    }

    console.log("\n=== Done ===");
}

main().catch(console.error);
