import {ethers} from "hardhat";
import {pendleDeposit} from "../actions/pendleDeposit";
import {giveTokenToAddresss} from "../../thief";
import {THIEF_TOKEN_CONFIG} from "defi-resources/build/ressources/erc20/thiefConfig";

import {Signer} from "ethers";
import {pendleWithdraw} from "../actions/pendleWithdraw";

type InInfo = {
    token: string;
    amount: bigint;
    market: string;
    underlying: string;
};

const main = async (inInfo: InInfo) => {
    
    let lpBalance = 0n;
    const user = (await ethers.getSigners())[0] as unknown as Signer;

    // Give the underlying to the user
    try {
        const config = THIEF_TOKEN_CONFIG[inInfo.token];

        if (!config) {
            throw new Error(`Token ${inInfo.token} not found in THIEF_TOKEN_CONFIG`);
        }

        // Give tokens to user
        await giveTokenToAddresss(user, config.address, inInfo.amount, config.slotBalance, config.isVyper);
    } catch (error) {
        console.error("Error during giveTokenToAddresss:", error);
        throw error;
    }

    // Deposit the underlying into the market
    try {
        await pendleDeposit(inInfo.market, inInfo.underlying, inInfo.amount, user);

        // Check LP balance after deposit
        const marketContract = await ethers.getContractAt("IPendleMarketV3", inInfo.market);
        const userAddress = await user.getAddress();
        lpBalance = await marketContract.balanceOf(userAddress);

        // withdraw
        if (lpBalance === 0n) {
            throw new Error("No LP tokens  received after deposit");
        }
    } catch (error) {
        console.error("Error during Pendle deposit:", error);
        throw error;
    }

    // Withdraw the LP tokens from the market
    try {
        await pendleWithdraw(inInfo.market, inInfo.underlying, lpBalance, user);
        const marketContract = await ethers.getContractAt("IPendleMarketV3", inInfo.market);
        const userAddress = await user.getAddress();
        lpBalance = await marketContract.balanceOf(userAddress);

        if (lpBalance > 0n) {
            throw new Error("still have LP tokens after withdraw");
        }
    } catch (error) {
        console.error("Error during Pendle withdraw:", error);
        throw error;
    }
};
(async () => {
    try {
        await main({
            token: "GHO",
            amount: ethers.parseEther("1000"),
            market: "0xC64D59eb11c869012C686349d24e1D7C91C86ee2",
            underlying: "0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f",
        });
    } catch (error) {
        console.error(error);
        process.exitCode = 1;
    }
})();
