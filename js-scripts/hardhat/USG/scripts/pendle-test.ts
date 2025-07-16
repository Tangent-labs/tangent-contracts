import {ethers} from "hardhat";
import {
    getPendleMarketContracts,
    pendleWithdrawLP,
    PendleMarketContracts,
    pendleWithdrawYT,
    pendleWithdrawPT,
    pendleDepositPTAndYT,
    pendleDepositLPP,
} from "../actions/pendleActions";

import {Signer} from "ethers";
import {giveTokenToAddresss} from "../../thief";
import {THIEF_TOKEN_CONFIG} from "defi-resources/build/ressources/erc20/thiefConfig";

type InInfo = {
    amount: bigint;
    market: string;
};

const testAll = async (inInfo: InInfo) => {
    const user = (await ethers.getSigners())[0] as unknown as Signer;
    const marketContracts = await getPendleMarketContracts(inInfo.market);
    const userAddress = await user.getAddress();

    const SY = marketContracts.sy;

    const tokensIn = await SY.getTokensIn();

    const underlyingContract = await ethers.getContractAt("IERC20Metadata", tokensIn[0]);

    const config = THIEF_TOKEN_CONFIG[await underlyingContract.symbol()];

    await giveTokenToAddresss(user, await underlyingContract.getAddress(), inInfo.amount * 10n, config.slotBalance, config.isVyper);

    /* ---------------------------------------- LP ---------------------------------------------*/
    await test_LP(marketContracts, userAddress, inInfo, user);

    /* ---------------------------------------- YT ---------------------------------------------*/
    await test_YT(marketContracts, userAddress, inInfo, user);

    /* ---------------------------------------- PT ---------------------------------------------*/
    await test_PT(marketContracts, userAddress, inInfo, user);

    console.log("Pendle test passed");
};

const test_LP = async (marketContract: PendleMarketContracts, userAddress: string, inInfo: InInfo, user: Signer) => {
    try {
        const lpBalanceBefore = await marketContract.market.balanceOf(userAddress);

        await pendleDepositLPP(inInfo.market, inInfo.amount, user);
        const lpBalanceAfter = await marketContract.market.balanceOf(userAddress);

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
        const lpBalanceBefore = await marketContract.market.balanceOf(userAddress);
        await pendleWithdrawLP(inInfo.market, lpBalanceBefore, user);
        const lpBalanceAfter = await marketContract.market.balanceOf(userAddress);

        if (lpBalanceAfter > lpBalanceBefore) {
            throw new Error("Withdraw failed, more LP tokens after");
        }
    } catch (error) {
        console.error("Error during Pendle withdraw:", error);
        throw error;
    }
};

const test_YT = async (marketContracts: PendleMarketContracts, userAddress: string, inInfo: InInfo, user: Signer) => {
    try {
        // deposit some LP

        const ytContract = marketContracts.yt;
        const ytBalanceBefore = await ytContract.balanceOf(userAddress);

        await pendleDepositPTAndYT(inInfo.market, inInfo.amount, user);

        // withdraw
        const ytBalanceAfter = await ytContract.balanceOf(userAddress);

        if (ytBalanceAfter < ytBalanceBefore) {
            throw new Error("Deposit failed, more YT tokens after");
        }
    } catch (error) {
        console.error("Error during Pendle deposit with YT retention:", error);
        throw error;
    }

    try {
        const ytContract = marketContracts.yt;
        const ytBalanceBefore = await ytContract.balanceOf(userAddress);

        // Withdraw YT tokens
        await pendleWithdrawYT(inInfo.market, ytBalanceBefore, user);

        // Check YT balance

        const ytBalanceAfter = await ytContract.balanceOf(userAddress);
        console.log(`ytBalance: ${ytBalanceBefore} -> ${ytBalanceAfter}`);

        if (ytBalanceAfter > ytBalanceBefore) {
            throw new Error("Less YT tokens received after pendleWithdrawYT");
        }
    } catch (error) {
        console.error("Error during pendleWithdrawYT test:", error);
        throw error;
    }
};

const test_PT = async (marketContracts: PendleMarketContracts, userAddress: string, inInfo: InInfo, user: Signer) => {
    try {
        const ptContract = marketContracts.pt;
        const ptBalanceBefore = await ptContract.balanceOf(userAddress);

        await pendleDepositPTAndYT(inInfo.market, inInfo.amount, user);
        // ptBalance
        const ptBalanceAfter = await ptContract.balanceOf(userAddress);

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

        const ptContract = marketContracts.pt;
        const ptBalanceBefore = await ptContract.balanceOf(userAddress);

        // Withdraw PT tokens
        await pendleWithdrawPT(inInfo.market, ptBalanceBefore, user);

        // Check PT balance
        const ptBalanceAfter = await ptContract.balanceOf(userAddress);

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
        await testAll({
            amount: ethers.parseEther("1000"),
            market: "0xC64D59eb11c869012C686349d24e1D7C91C86ee2",
        });
    } catch (error) {
        console.error(error);
        process.exitCode = 1;
    }
})();

// npx hardhat run  js-scripts/hardhat/USG/scripts/pendle-test.ts
