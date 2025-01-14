import {parseEther} from "ethers";
import {ethers} from "hardhat";
import * as contractAddresses from "../../../../addresses.json";
import {MainSetup} from "../../Main.setup";

export async function stake() {
    const mainSetup = new MainSetup();
    await mainSetup.setupTestUsers();
    const allMarkets = contractAddresses.markets;
    for (let i = 0; i < allMarkets.length; i++) {
        const market = await ethers.getContractAt("MarketNoSociabilization", allMarkets[i].marketAddress);
        const collatToken = await ethers.getContractAt("ERC20", await market.collatToken());

        for (let j = 0; j < mainSetup.users.length; j++) {
            const user = mainSetup.users[j];

            await collatToken.connect(user).approve(market, ethers.MaxUint256);
            await market.connect(user).deposit(user, parseEther("100"), true);
        }
    }

    console.info("\x1b[32m%s\x1b[0m", "Staking on market with success !");
}

stake();
