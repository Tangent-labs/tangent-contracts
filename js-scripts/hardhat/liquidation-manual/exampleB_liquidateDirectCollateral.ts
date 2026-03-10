/**
 * Example B - Liquidation with direct collateral retrieval (flash-loan pattern)
 *
 * Demonstrates the direct liquidation flow:
 *   1. The liquidator holds USG (simulating a flash loan providing it)
 *   2. Calls market.liquidate() with router = address(0)
 *   3. Receives collateral directly
 *   4. Can then swap collateral -> USG off-chain to repay flash loan
 *
 * Prerequisites:
 *   - Run liquidationSetUp.ts first (creates positions + drops oracle prices)
 *
 * Usage:
 *   npx hardhat run js-scripts/hardhat/liquidation-manual/exampleB_liquidateDirectCollateral.ts --network localhost
 */
import {ethers, network} from "hardhat";
import {formatEther} from "ethers";
import {loadAddresses} from "../USG/actions/common";
import {impersonateAccount, stopImpersonatingAccount, setBalance} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import {
    DeployedAddresses,
    getCandidateUsers,
    findFirstLiquidablePosition,
    computeUsgNeeded,
    computeSafeLiquidationParams,
    printPosition,
    formatShortAddress,
} from "./helpers";

async function main() {
    await network.provider.send("evm_setAutomine", [true]);

    const signers = await ethers.getSigners();
    const liquidator = signers[3]; // Use a signer that is NOT a position holder
    const liquidatorAddress = await liquidator.getAddress();

    console.log("=== Example B: Liquidation with direct collateral retrieval ===\n");
    console.log(`Liquidator: ${liquidatorAddress}`);

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
    const usg = await ethers.getContractAt("USG", usgAddr);

    // --- Scan for liquidable positions ---
    console.log("\n--- Scanning for liquidable positions ---\n");

    const userAddresses = await getCandidateUsers();
    const pos = await findFirstLiquidablePosition(addresses, marketViewer, userAddresses);

    if (!pos) {
        console.log("No liquidable positions found. Make sure liquidationSetUp.ts has been run.");
        console.log("=== Done ===");
        return;
    }

    printPosition(pos);

    const {collatToken, fee, usgNeeded} = await computeUsgNeeded(pos.market, pos.collatBalance, pos.userDebt);
    const collatSymbol = await collatToken.symbol();
    console.log(`  USG needed: ${formatEther(usgNeeded)} (debt ${formatEther(pos.userDebt)} + fee ${formatEther(fee)})`);

    // --- Fund liquidator with USG (simulating flash loan) ---
    let funded = false;
    for (const addr of userAddresses) {
        if (addr === pos.userAddress || addr === liquidatorAddress) continue;

        const bal = await usg.balanceOf(addr);
        if (bal >= usgNeeded) {
            await setBalance(addr, ethers.parseEther("10"));
            await impersonateAccount(addr);
            const whale = await ethers.getSigner(addr);
            await usg.connect(whale).transfer(liquidatorAddress, usgNeeded);
            await stopImpersonatingAccount(addr);
            funded = true;
            console.log(`  Funded liquidator from ${formatShortAddress(addr)}`);
            break;
        }
    }

    if (!funded) {
        console.log("  Could not fund liquidator. Skipping.");
        console.log("=== Done ===");
        return;
    }

    const safeParams = computeSafeLiquidationParams(usgNeeded, pos.collatBalance, pos.userDebt, false);
    await usg.connect(liquidator).approve(pos.marketAddress, safeParams.maxUsgToBurn);

    const collatBefore = await collatToken.balanceOf(liquidatorAddress);

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
        {router: ethers.ZeroAddress, routerCall: "0x"}
    );

    const receipt = await tx.wait();

    const collatAfter = await collatToken.balanceOf(liquidatorAddress);
    const collatReceived = collatAfter - collatBefore;

    console.log(`\n  TX: ${receipt?.hash}`);
    console.log(`  Collateral received: ${formatEther(collatReceived)} ${collatSymbol}`);
    console.log("  In production: swap this collateral -> USDC to repay flash loan");
    console.log("  Profit = collateral value - debt - fee - flash loan premium");

    const debtAfter = await marketViewer.userDebt(pos.marketAddress, pos.userAddress);
    console.log(`  Remaining debt: ${formatEther(debtAfter)} USG`);
    console.log("=== Done ===");
}

main().catch(console.error);
