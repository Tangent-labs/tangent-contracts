import {chainView} from "../../../chainView";
import chainViewMarketAccountArtifact from "../../../../artifacts/src/chainview/USG/bot/MarketAccountLiquidationBotInfo.cv.sol/MarketAccountLiquidationBotInfo.json";
import {LiquidationUserInInfo, LiquidationMarketAccountInfo} from "../contexts/LiquidationContext";
import {formatEther} from "ethers";
import * as fs from "fs";
import {ethers} from "hardhat";

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
    console.log("🔍 Checking liquidation status...");

    // Load existing addresses if available
    let addresses;
    try {
        const cwd = process.cwd();
        const addressesData = fs.readFileSync(cwd + "/addresses.json", "utf8");
        addresses = JSON.parse(addressesData);
        console.log("✅ Loaded existing addresses from addresses.json");
    } catch (error) {
        console.log("❌ No addresses.json found. Please run liquidation-context first.");
        return;
    }

    // Fetch liquidation data from chain using chain view
    console.log("📊 Fetching liquidation data from chain...");

    // Get market addresses from the loaded data
    const marketAddresses = addresses.markets?.map((market: any) => market.marketAddress) || [];
    const users = (await ethers.getSigners())?.slice(0, 5);

    const userAddresses = (await Promise.all(users.map((user: any) => user.getAddress()))) || [];
    console.log(userAddresses);

    if (marketAddresses.length === 0 || userAddresses.length === 0) {
        console.log("❌ No markets or users found in addresses.json");
        return;
    }

    console.log(`📈 Found ${marketAddresses.length} markets and ${userAddresses.length} users`);

    // Create parameters for chain view
    const params = marketAddresses
        .map((marketAddress: string) =>
            userAddresses.map((userAddress: string) => {
                return {
                    account: userAddress,
                    market: marketAddress,
                };
            })
        )
        .flat();

    //console.log(params);

    try {
        // Execute chain view to get liquidation data
        const userAccountsData = await chainView<[string[], LiquidationUserInInfo[]], [LiquidationMarketAccountInfo]>(
            chainViewMarketAccountArtifact.abi,
            chainViewMarketAccountArtifact.bytecode,
            [marketAddresses, params]
        );

        if (!userAccountsData || !userAccountsData[0]) {
            console.log("❌ No liquidation data returned from chain view");
            return;
        }

        //console.log(userAccountsData);

        console.log("\n📋 LIQUIDATION STATUS REPORT");
        console.log("=".repeat(50));

        const markets = userAccountsData[0].markets?.map((m) => m.toObject());

        // Process each market's data
        const debtAccounts = userAccountsData[0]?.accounts?.map((a) => a.toObject());

        const seizingList: LiquidationUserFullInfo[] = [];
        const liquidationList: LiquidationUserFullInfo[] = [];

        let paramIndex = 0;
        for (const debtAccountIndex in debtAccounts) {
            const debtAccount = debtAccounts[debtAccountIndex];
            const param = params[paramIndex];
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
            if (account.userDebt >= account.positionValue) {
                seizingList.push(account);
            } else if (account.ltv > account.liquidationThreshold) {
                liquidationList.push(account);
            }

            const marketInfo = addresses.markets?.find((m: any) => m.marketAddress === param.market);
            const healthRatioPercent = Number(formatEther(healthRatio)) * 100;
            const ltvPercent = Number(ltv) / 1000;
            if (userDebt > 0n) {
                console.log(`👤 User: ${userAddress.slice(0, 8)}...${userAddress.slice(-6)} / Market : ${marketInfo.collatName} `);
                console.log(`   Max LTV: ${Number(marketData.maxLTV) / 1000}%`);
                console.log(`   Liquidation Threshold: ${Number(marketData.liquidationThreshold) / 1000}%`);
                console.log(`   LTV: ${ltvPercent.toFixed(2)}%`);
                console.log(`   Health Ratio: ${healthRatioPercent.toFixed(2)}%`);
                console.log(`   Debt: ${formatEther(userDebt)} USG`);
                console.log(`   Position Value: $${formatEther(positionValue)}`);
                if (seizingList.some((a) => a.account === userAddress && a.market === param.market)) {
                    console.log(`   Status: 🔴 SEIZABLE`);
                } else if (liquidationList.some((a) => a.account === userAddress && a.market === param.market)) {
                    console.log(`   Status: 🔴 LIQUIDATABLE`);
                } else {
                    console.log(`   Status: 🟢 Safe`);
                }
                console.log("");
            }

            paramIndex++;
        }

        // Display summary
        console.log("\n📊 LIQUIDATION SUMMARY");
        console.log("=".repeat(50));
        console.log(`🔴 Seizable accounts: ${new Set(seizingList.map((a) => a.market)).size}`);
        console.log(`🔴 Liquidatable accounts: ${new Set(liquidationList.map((a) => a.market)).size}`);

        // list of markets by collatName with the numnber of Safe / LIQUIDATABLE / SEIZABLE
        const marketSummary = markets?.map((m) => {
            const safe = seizingList.filter((a) => a.market === m.market).length || 0;
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

        // ist of the liquiditable market  by distinct name
        const liquiditableMarkets = [...new Set(liquidationList.map((a) => addresses.markets?.find((m: any) => m.marketAddress === a.market)?.collatName))];
        console.log(`🔴 Liquiditable markets: ${liquiditableMarkets.join(", ")}`);

        // list of the seizing market by distinct name
        const seizingMarkets = [...new Set(seizingList.map((a) => addresses.markets?.find((m: any) => m.marketAddress === a.market)?.collatName))];
        console.log(`🔴 Seizing markets: ${seizingMarkets.join(", ")}`);

        // if (seizingList.length > 0) {
        //     console.log("\n🔴 SEIZABLE ACCOUNTS:");
        //     seizingList.forEach((account) => {
        //         const marketInfo = addresses.markets?.find((m: any) => m.marketAddress === account.market);
        //         console.log(`   - ${account.account.slice(0, 8)}...${account.account.slice(-6)} / ${marketInfo?.collatName || account.market}`);
        //         console.log(`     Debt: ${formatEther(account.userDebt)} USG >= Position: $${formatEther(account.positionValue)}`);
        //     });
        // }

        // if (liquidationList.length > 0) {
        //     console.log("\n🔴 LIQUIDATABLE ACCOUNTS:");
        //     liquidationList.forEach((account) => {
        //         const marketInfo = addresses.markets?.find((m: any) => m.marketAddress === account.market);
        //         const ltvPercent = Number(account.ltv) / 1000;
        //         const thresholdPercent = Number(account.liquidationThreshold) / 1000;
        //         console.log(`   - ${account.account.slice(0, 8)}...${account.account.slice(-6)} / ${marketInfo?.collatName || account.market}`);
        //         console.log(`     LTV: ${ltvPercent.toFixed(2)}% > Threshold: ${thresholdPercent.toFixed(2)}%`);
        //     });
        // }
    } catch (error) {
        console.error("❌ Error checking liquidation status:", error);
    }
}

console.log("Checking liquidation status...");
main().catch((error) => {
    console.error("❌ Script failed:", error);
    process.exit(1);
});
