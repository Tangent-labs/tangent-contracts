import { ethers } from "hardhat";
import { pendleWithdrawYT, pendleWithdrawPT, pendleDepositPTAndYT, pendleDepositLP, pendleWithdrawLP, PendleKeys } from "../actions/pendleActions";

import { formatEther, parseEther, Signer } from "ethers";
import { giveTokenToAddresss } from "../../thief/thief";
import { THIEF_TOKEN_CONFIG } from "@tangent/defi-resources/build/ressources/erc20/thiefConfig";
import { PENDLE_POOLS } from "@tangent/defi-resources";

const testAll = async (key: PendleKeys) => {
    const user = (await ethers.getSigners())[0] as unknown as Signer;
    const syToken = await ethers.getContractAt("IPendleSYToken", PENDLE_POOLS[key].SY);

    const tokensIn = await syToken.getTokensIn();

    const underlyingContract = await ethers.getContractAt("IERC20Metadata", tokensIn[0]);

    const config = THIEF_TOKEN_CONFIG[await underlyingContract.symbol()];

    await giveTokenToAddresss(user, await underlyingContract.getAddress(), ethers.parseEther("1000") * 10n, config.slotBalance, config.isVyper);

    /* ---------------------------------------- LP ---------------------------------------------*/
    await test_LP("fGHO 07/31/25", 1000, user);

    /* ---------------------------------------- YT ---------------------------------------------*/
    await test_YT("fGHO 07/31/25", 1000, user);

    /* ---------------------------------------- PT ---------------------------------------------*/
    await test_PT("fGHO 07/31/25", 1000, user);

    console.log("Pendle test passed");
};

const test_LP = async (key: PendleKeys, amount: number, user: Signer) => {
    const market = await ethers.getContractAt("IPendleMarketV3", PENDLE_POOLS[key].MARKET);
    try {
        const lpBalanceBefore = await market.balanceOf(user);

        await pendleDepositLP(key, user, amount);
        const lpBalanceAfter = await market.balanceOf(user);

        // withdraw
        if (lpBalanceAfter < lpBalanceBefore) {
            throw new Error("Deposit failed, lesseq LP tokens after ");
        }
    } catch (error) {
        console.error("Error during Pendle deposit:", error);
        throw error;
    }

    // Withdraw the LP tokens from the market
    try {
        const lpBalanceBefore = await market.balanceOf(user);
        await pendleWithdrawLP(key, user, Number(formatEther(lpBalanceBefore)));
        const lpBalanceAfter = await market.balanceOf(user);

        if (lpBalanceAfter > lpBalanceBefore) {
            throw new Error("Withdraw failed, more LP tokens after");
        }
    } catch (error) {
        console.error("Error during Pendle withdraw:", error);
        throw error;
    }
};

const test_YT = async (key: PendleKeys, amount: number, user: Signer) => {
    const yt = await ethers.getContractAt("IPendleYTToken", PENDLE_POOLS[key].YT);

    try {
        // deposit some LP

        const ytBalanceBefore = await yt.balanceOf(user);

        await pendleDepositPTAndYT(key, user, amount);

        // withdraw
        const ytBalanceAfter = await yt.balanceOf(user);

        if (ytBalanceAfter < ytBalanceBefore) {
            throw new Error("Deposit failed, more YT tokens after");
        }
    } catch (error) {
        console.error("Error during Pendle deposit with YT retention:", error);
        throw error;
    }

    try {
        const ytBalanceBefore = await yt.balanceOf(user);

        // Withdraw YT tokens
        await pendleWithdrawYT(key, user, Number(formatEther(ytBalanceBefore)));

        // Check YT balance

        const ytBalanceAfter = await yt.balanceOf(user);
        console.log(`ytBalance: ${ytBalanceBefore} -> ${ytBalanceAfter}`);

        if (ytBalanceAfter > ytBalanceBefore) {
            throw new Error("Less YT tokens received after pendleWithdrawYT");
        }
    } catch (error) {
        console.error("Error during pendleWithdrawYT test:", error);
        throw error;
    }
};

const test_PT = async (key: PendleKeys, amount: number, user: Signer) => {
    const pt = await ethers.getContractAt("IERC20Metadata", PENDLE_POOLS[key].PT);

    try {
        const ptBalanceBefore = await pt.balanceOf(user);

        await pendleDepositPTAndYT(key, user, amount);
        // ptBalance
        const ptBalanceAfter = await pt.balanceOf(user);

        if (ptBalanceAfter < ptBalanceBefore) {
            throw new Error("Deposit failed, less PT tokens after");
        }
    } catch (error) {
        console.error("Error during Pendle withdraw single PT:", error);
        throw error;
    }

    // Test pendleWithdrawPT
    try {
        // First deposit some LP tokens to have something to withdraw

        const ptBalanceBefore = await pt.balanceOf(user);

        // Withdraw PT tokens
        await pendleWithdrawPT(key, user, Number(formatEther(ptBalanceBefore)));

        // Check PT balance
        const ptBalanceAfter = await pt.balanceOf(user);

        if (ptBalanceAfter > ptBalanceBefore) {
            throw new Error("Less PT tokens received after pendleWithdrawPT");
        }
    } catch (error) {
        console.error("Error during pendleWithdrawPT test:", error);
        throw error;
    }
};

(async () => {
    try {
        await testAll("fGHO 07/31/25");
    } catch (error) {
        console.error(error);
        process.exitCode = 1;
    }
})();

// npx hardhat run  js-scripts/hardhat/USG/scripts/pendle-test.ts
