import {chainView} from "../../../chainView";
import chainViewMarketAccountArtifact from "../../../../artifacts/src/chainview/USG/bot/MarketAccountLiquidationBotInfo.cv.sol/MarketAccountLiquidationBotInfo.json";
import {LiquidationUserInInfo, LiquidationMarketAccountInfo, LiquidationContext} from "../contexts/LiquidationContext";
import * as fs from "fs";
import {ethers} from "hardhat";
import {CHAOS_CONFIG} from "./liquidationSetUpChaos";

// DENOMINATOR from Collateral.sol (100_000 = 100%)
const DENOMINATOR = 100_000n;

type LiquidationUserFullInfo = {
    account: string;
    market: string;
    healthRatio: bigint;
    userDebt: bigint;
    positionValue: bigint;
    ltv: bigint;
    liquidationThreshold: bigint;
};

async function main() {
    console.log("🔍 Checking liquidation status (CHAOS MODE - 300 users)...");

    // Load existing addresses if available
    let addresses;
    try {
        const cwd = process.cwd();
        const addressesData = fs.readFileSync(cwd + "/addresses.json", "utf8");
        addresses = JSON.parse(addressesData);
        console.log("✅ Loaded existing addresses from addresses.json");
    } catch (error) {
        console.log("❌ No addresses.json found. Please run liquidation-context-chaos first.");
        return;
    }

    // Fetch liquidation data from chain using chain view
    console.log("📊 Fetching liquidation data from chain...");
    const liquidationContext = new LiquidationContext(CHAOS_CONFIG);

    // Get market addresses from the loaded data
    const marketAddresses = addresses.markets?.map((market: any) => market.marketAddress) || [];
    // Use all users for chaos mode
    const allSigners = await ethers.getSigners();
    const users = allSigners.slice(0, CHAOS_CONFIG.USER_COUNT); // Use all users from config

    const userAddresses = await Promise.all(users.map((user: any) => user.getAddress()));
    console.log(`📊 Checking ${userAddresses.length} users across ${marketAddresses.length} markets`);

    if (marketAddresses.length === 0 || userAddresses.length === 0) {
        console.log("❌ No markets or users found in addresses.json");
        return;
    }

    console.log(`📈 Found ${marketAddresses.length} markets and ${userAddresses.length} users`);

    // Get marketViewer address
    const marketViewerAddress = addresses.utilities?.marketViewer;
    if (!marketViewerAddress) {
        console.log("❌ MarketViewer address not found in addresses.json");
        return;
    }

    // Batch size for processing users
    const BATCH_SIZE = 10;
    const totalBatches = Math.ceil(userAddresses.length / BATCH_SIZE);
    console.log(`📦 Processing ${totalBatches} batches of up to ${BATCH_SIZE} users each`);

    try {
        // Aggregate results from all batches
        let aggregatedMarkets: any[] = [];
        let aggregatedAccounts: any[] = [];
        let allParams: LiquidationUserInInfo[] = [];

        // Process users in batches
        for (let batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
            const startIndex = batchIndex * BATCH_SIZE;
            const endIndex = Math.min(startIndex + BATCH_SIZE, userAddresses.length);
            const batchUserAddresses = userAddresses.slice(startIndex, endIndex);

            console.log(`\n📦 Processing batch ${batchIndex + 1}/${totalBatches} (users ${startIndex + 1}-${endIndex})...`);

            // Create parameters for this batch
            const batchParams = marketAddresses
                .map((marketAddress: string) =>
                    batchUserAddresses.map((userAddress: string) => {
                        return {
                            account: userAddress,
                            market: marketAddress,
                        };
                    })
                )
                .flat();

            // Execute chain view for this batch (using old signature with ethers.provider by default)
            const batchData = await chainView<[LiquidationMarketAccountInfo]>(
                chainViewMarketAccountArtifact.abi,
                chainViewMarketAccountArtifact.bytecode,
                [marketAddresses, batchParams, marketViewerAddress]
            );

            if (!batchData || !batchData[0]) {
                console.log(`⚠️  No data returned for batch ${batchIndex + 1}`);
                continue;
            }

            // Aggregate markets (only need to store once, they're the same for all batches)
            if (aggregatedMarkets.length === 0) {
                aggregatedMarkets = batchData[0].markets?.map((m) => m.toObject()) || [];
            }

            // Aggregate accounts from this batch
            const batchAccounts = batchData[0]?.accounts?.map((a) => a.toObject()) || [];
            aggregatedAccounts = aggregatedAccounts.concat(batchAccounts);
            allParams = allParams.concat(batchParams);

            console.log(`✅ Batch ${batchIndex + 1} completed: ${batchAccounts.length} accounts processed`);
        }

        if (aggregatedAccounts.length === 0) {
            console.log("❌ No liquidation data returned from chain view");
            return;
        }

        console.log(`\n✅ All batches processed. Total accounts: ${aggregatedAccounts.length}`);
        console.log("\n📋 LIQUIDATION STATUS REPORT");
        console.log("=".repeat(50));

        const markets = aggregatedMarkets;
        const debtAccounts = aggregatedAccounts;

        const seizingList: LiquidationUserFullInfo[] = [];
        const liquidationList: LiquidationUserFullInfo[] = [];
        const safeList: LiquidationUserFullInfo[] = [];

        let paramIndex = 0;
        for (const debtAccountIndex in debtAccounts) {
            const debtAccount = debtAccounts[debtAccountIndex];
            const param = allParams[paramIndex];
            if (!param) {
                console.error("No params founded ");
                continue;
            }
            const marketData = markets?.find((market) => market.market === param.market);
            if (!marketData) {
                console.error("No market Data");
                continue;
            }

            const healthRatio = debtAccount.healthRatio;
            const userDebt = debtAccount.userDebt;
            const positionValue = debtAccount.positionValue;
            const userAddress = param.account;
            if (userDebt === 0n) {
                paramIndex++;
                continue;
            }

            // Calculate LTV: (userDebt * DENOMINATOR) / positionValue
            const ltv = positionValue > 0n ? (userDebt * DENOMINATOR) / positionValue : 0n;

            const account: LiquidationUserFullInfo = {
                account: userAddress,
                market: param.market,
                healthRatio,
                userDebt,
                positionValue,
                ltv,
                liquidationThreshold: marketData.liquidationThreshold,
            };

            // Categorize account based on liquidation/seizing logic
            // Use healthRatio (as the contract does) instead of LTV for more accurate categorization
            // healthRatio < 1e18 means liquidatable (as per MarketExternalActions.sol line 217)
            if (account.userDebt >= account.positionValue) {
                seizingList.push(account);
            } else if (account.healthRatio < 10n ** 18n) {
                // healthRatio < 1 means liquidatable (same logic as contract)
                liquidationList.push(account);
            } else {
                safeList.push(account);
            }

            paramIndex++;
        }

        // Display summary
        console.log("\n📊 LIQUIDATION SUMMARY");
        console.log("=".repeat(50));
        console.log(`🟢 Safe accounts: ${safeList.length}`);
        console.log(`🔴 Liquidatable accounts: ${liquidationList.length}`);
        console.log(`🔴 Seizable accounts: ${seizingList.length}`);
        console.log(`📊 Total accounts with debt: ${safeList.length + liquidationList.length + seizingList.length}`);

        // list of markets by collatName with the number of Safe / LIQUIDATABLE / SEIZABLE
        const marketSummary = markets?.map((m) => {
            const safe = safeList.filter((a) => a.market === m.market).length || 0;
            const liquidatable = liquidationList.filter((a) => a.market === m.market).length || 0;
            const seizing = seizingList.filter((a) => a.market === m.market).length || 0;
            return {
                collatName: addresses.markets?.find((a: any) => a.marketAddress.toLowerCase() === m.market.toLowerCase())?.collatName || "-",
                safe,
                Liquidatable: liquidatable,
                Seizable: seizing,
            };
        });
        console.table(marketSummary, ["collatName", "safe", "Liquidatable", "Seizable"]);

        // list of the liquiditable market by distinct name
        const liquiditableMarkets = [...new Set(liquidationList.map((a) => addresses.markets?.find((m: any) => m.marketAddress === a.market)?.collatName))];
        console.log(`🔴 Liquiditable markets: ${liquiditableMarkets.join(", ")}`);

        // list of the seizing market by distinct name
        const seizingMarkets = [...new Set(seizingList.map((a) => addresses.markets?.find((m: any) => m.marketAddress === a.market)?.collatName))];
        console.log(`🔴 Seizing markets: ${seizingMarkets.join(", ")}`);
    } catch (error) {
        console.error("❌ Error checking liquidation status:", error);
    }
}

console.log("Checking liquidation status (CHAOS MODE)...");
main().catch((error) => {
    console.error("❌ Script failed:", error);
    process.exit(1);
});
