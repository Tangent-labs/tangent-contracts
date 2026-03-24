/**
 * Utility — Check all positions for liquidation status
 *
 * Scans all markets and hardhat signers to display:
 *   - Health ratio
 *   - Position value vs debt
 *   - Liquidation mode available (liquidate / selfLiquidate / seizeCollateral)
 *
 * Prerequisites:
 *   - Run liquidationSetUp.ts first to deploy contracts, create positions, and set mock oracles
 *
 * Usage:
 *   npx hardhat run js-scripts/hardhat/liquidation-manual/checkLiquidablePositions.ts --network localhost
 */
import {ethers, network} from "hardhat";
import {formatEther} from "ethers";
import {loadAddresses} from "../USG/actions/common";
import {HR_ONE, DeployedAddresses, getCandidateUsers, formatShortAddress} from "./helpers";

// Minimal ABIs
const MARKET_ABI = [
    "function maxLTV() view returns (uint256)",
    "function liquidationThreshold() view returns (uint256)",
    "function collateralBalances(address) view returns (uint256)",
];
const MARKET_VIEWER_ABI = [
    "function healthRatio(address market, address user) view returns (uint256)",
    "function userDebt(address market, address user) view returns (uint256)",
    "function positionValue(address market, address user) view returns (uint256)",
];

async function main() {
    // Ensure automine is on so we can read state
    await network.provider.send("evm_setAutomine", [true]);

    console.log("=== Liquidation Status Check ===\n");

    let addresses: DeployedAddresses;
    try {
        addresses = loadAddresses() as DeployedAddresses;
    } catch {
        console.error("addresses.json not found. Run liquidationSetUp.ts first.");
        return;
    }

    const marketViewerAddr = addresses.utilities?.marketViewer;
    if (!marketViewerAddr) {
        console.error("marketViewer address not found in addresses.json");
        return;
    }

    const marketViewer = new ethers.Contract(marketViewerAddr, MARKET_VIEWER_ABI, ethers.provider);

    // Get hardhat signers as potential position holders
    const userAddresses = await getCandidateUsers();
    console.log(`Checking positions for users: ${userAddresses.map(formatShortAddress).join(", ")}`);

    let totalPositions = 0;
    let liquidable = 0;
    let seizable = 0;
    let healthy = 0;

    for (const marketInfo of addresses.markets || []) {
        const marketAddress = marketInfo.marketAddress;
        const collatName = marketInfo.collatName;

        const market = new ethers.Contract(marketAddress, MARKET_ABI, ethers.provider);

        try {
            const code = await ethers.provider.getCode(marketAddress);
        //    console.log(`\nChecking market: ${collatName} (${marketAddress}) - Code size: ${code.length / 2 - 1} bytes  / ${code}`);
            if (code === "0x") {
                console.log(`\n--- Market: ${collatName} — [SKIP] No contract ---`);
                continue;
            }

            console.log(`\n--- Market: ${collatName} (${marketAddress}) ---`);

            try {
                const maxLTV = await market.maxLTV();
                const liqThreshold = await market.liquidationThreshold();
                console.log(`  maxLTV: ${(Number(maxLTV) / 1000).toFixed(1)}%  liqThreshold: ${(Number(liqThreshold) / 1000).toFixed(1)}%`);
            } catch {
                console.log("  [WARN] Could not read market params");
            }

            for (const userAddress of userAddresses) {
                try {
                   // const collatBalance = await market.collateralBalances(userAddress);
                    
                    //if (collatBalance === 0n) continue;

                    totalPositions++;

                    const hr = await marketViewer.healthRatio(marketAddress, userAddress);
                    const userDebt = await marketViewer.userDebt(marketAddress, userAddress);
                    const posValue = await marketViewer.positionValue(marketAddress, userAddress);

                    let status: string;
                    if (posValue < userDebt) {
                        status = "SEIZABLE (bad debt)";
                        seizable++;
                    } else if (hr < HR_ONE) {
                        status = "LIQUIDABLE";
                        liquidable++;
                    } else {
                        status = "HEALTHY";
                        healthy++;
                    }

                    const shortAddr = formatShortAddress(userAddress);
                    console.log(
                        `  ${shortAddr} | HR: ${formatEther(hr).slice(0, 8)} | Debt: ${formatEther(userDebt).slice(0, 10)} USG | Value: ${formatEther(posValue).slice(0, 10)} USG | ${status}`
                    );
                } catch {
                    // User has no position or call failed
                }
            }
        } catch (e: any) {
            console.log(`  [ERROR] ${e.message?.slice(0, 100)}`);
        }
    }

    console.log(`\n=== Summary ===`);
    console.log(`Total positions: ${totalPositions}`);
    console.log(`  Healthy:    ${healthy}`);
    console.log(`  Liquidable: ${liquidable}`);
    console.log(`  Seizable:   ${seizable}`);

    if (totalPositions === 0) {
        console.log("\nNo positions found. Make sure liquidationSetUp.ts has been run first.");
    }
}

main().catch(console.error);
