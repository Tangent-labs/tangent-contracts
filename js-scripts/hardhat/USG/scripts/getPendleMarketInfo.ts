import {ethers} from "hardhat";
import {getPendleMarketInfo} from "../actions/pendleActions";

const main = async () => {
    // Example Pendle market addresses (you can replace these with actual market addresses)
    const exampleMarkets = [
        {
            name: "eUSDe Market",
            address: "0x85667e484a32d884010Cf16427D90049CCf46e97",
        },
        {
            name: "eBTC Market",
            address: "0x523f9441853467477b4dDE653c554942f8E17162",
        },
        {
            name: "sUSDe Market",
            address: "0x4339Ffe2B7592Dc783ed13cCE310531aB366dEac",
        },
    ];

    console.log("=== Pendle Market Information Demo ===\n");

    for (const market of exampleMarkets) {
        try {
            console.log(`\n--- ${market.name} ---`);
            const marketInfo = await getPendleMarketInfo(market.address);

            // You can access specific information from the returned object
            console.log(`\nDetailed Info:`);
            console.log(`- Market Address: ${marketInfo.marketAddress}`);
            console.log(`- SY Token: ${marketInfo.sy.name} (${marketInfo.sy.symbol})`);
            console.log(`- PT Token: ${marketInfo.pt.name} (${marketInfo.pt.symbol})`);
            console.log(`- YT Token: ${marketInfo.yt.name} (${marketInfo.yt.symbol})`);
            console.log(`- Input Tokens: ${marketInfo.sy.tokensIn.join(", ")}`);
            console.log(`- Output Tokens: ${marketInfo.sy.tokensOut.join(", ")}`);
            console.log(`- Expiry: ${marketInfo.formatted.expiryDate}`);
            console.log(`- Is Expired: ${marketInfo.formatted.isExpired}`);
        } catch (error) {
            console.error(`Error getting info for ${market.name}:`, error);
        }
    }
};

(async () => {
    try {
        await main();
    } catch (error) {
        console.error("Error in main:", error);
        process.exitCode = 1;
    }
})();
