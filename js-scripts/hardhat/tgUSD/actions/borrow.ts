import {parseEther} from "ethers";
import {ethers} from "hardhat";
import * as contractAddresses from "../../../../addresses.json";
import {MainSetup} from "../../Main.setup";

export async function borrow() {
    const mainSetup = new MainSetup();
    await mainSetup.setupTestUsers();
    const allMarkets = contractAddresses.markets;
    for (let i = 0; i < allMarkets.length; i++) {
        const market = await ethers.getContractAt("MarketNoSociabilization", allMarkets[i].marketAddress);

        for (let j = 0; j < mainSetup.users.length; j++) {
            const user = mainSetup.users[j];

            await market.connect(user).borrow(user, parseEther("7000"));
        }
    }

    console.info("\x1b[32m%s\x1b[0m", "Borrow tgUSD on market succeeded !");
}

borrow();
