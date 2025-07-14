import {ethers} from "hardhat";
import {
    getPendleMarketContracts,
    pendleDepositLP,
    pendleDepositYT,
    pendleWithdrawLP,
    pendleDepositPT,
    pendleWithdrawPT,
    pendleWithdrawYT,
    PendleMarketContracts,
    giveToken,
} from "../actions/pendleActions";

import {Signer} from "ethers";

type InInfo = {
    token: string;
    amount: bigint;
    market: string;
    underlying: string;
};

const testAll = async (inInfo: InInfo) => {
    const user = (await ethers.getSigners())[0] as unknown as Signer;
    const marketContracts = await getPendleMarketContracts(inInfo.market);
    const userAddress = await user.getAddress();

    const underlyingContract = await ethers.getContractAt("IERC20Metadata", inInfo.underlying);
    await giveToken(underlyingContract, inInfo.amount * 10n, user);

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

        await pendleDepositLP(inInfo.market, inInfo.amount, user, inInfo.underlying);
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
        await pendleWithdrawLP(inInfo.market, lpBalanceBefore, user, inInfo.underlying);
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
        await pendleDepositLP(inInfo.market, inInfo.amount, user, inInfo.underlying);
        const lpBalance = await marketContracts.market.balanceOf(userAddress);

        const ytContract = marketContracts.yt;
        const ytBalanceBefore = await ytContract.balanceOf(userAddress);
        console.log("pendleDepositYT");
        await pendleDepositYT(inInfo.market, inInfo.amount, user, inInfo.underlying);

        // withdraw
        const ytBalanceAfter = await ytContract.balanceOf(userAddress);
        const lpBalanceAfter = await marketContracts.market.balanceOf(userAddress);
        console.log(`lpBalance: ${lpBalance} -> ${lpBalanceAfter}`);
        console.log(`ytBalance: ${ytBalanceBefore} -> ${ytBalanceAfter}`);

        if (ytBalanceAfter < ytBalanceBefore) {
            throw new Error("Deposit failed, more YT tokens after");
        }
    } catch (error) {
        console.error("Error during Pendle deposit with YT retention:", error);
        throw error;
    }

    try {
        //await pendleDepositLP(inInfo.market, inInfo.underlying, inInfo.amount, user);
        // First deposit some LP tokens to have something to withdraw
        //await pendleDepositLP(inInfo.market, inInfo.underlying, inInfo.amount, user);
        const lpBalance = await marketContracts.market.balanceOf(userAddress);

        const ytContract = marketContracts.yt;
        const ytBalanceBefore = await ytContract.balanceOf(userAddress);

        // Withdraw YT tokens
        console.log("pendleWithdrawYT");
        await pendleWithdrawYT(inInfo.market, ytBalanceBefore, user);

        // Check YT balance

        const ytBalanceAfter = await ytContract.balanceOf(userAddress);
        const lpBalanceAfter = await marketContracts.market.balanceOf(userAddress);
        console.log(`lpBalance: ${lpBalance} -> ${lpBalanceAfter}`);
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
        await pendleDepositLP(inInfo.market, inInfo.amount, user, inInfo.underlying);
        const lpBalanceBefore = await marketContracts.market.balanceOf(userAddress);

        const ptContract = marketContracts.pt;
        const ptBalanceBefore = await ptContract.balanceOf(userAddress);

        await pendleDepositPT(inInfo.market, lpBalanceBefore, user);
        // ptBalance
        const lpBalanceAfter = await marketContracts.market.balanceOf(userAddress);
        const ptBalanceAfter = await ptContract.balanceOf(userAddress);
        console.log("pendleDepositPT");

        console.log(`lpBalance: ${lpBalanceBefore} -> ${lpBalanceAfter}`);
        console.log(`ptBalance: ${ptBalanceBefore} -> ${ptBalanceAfter}`);

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
        await pendleDepositLP(inInfo.market, inInfo.amount, user, inInfo.underlying);
        const lpBalance = await marketContracts.market.balanceOf(userAddress);

        const ptContract = marketContracts.pt;
        const ptBalanceBefore = await ptContract.balanceOf(userAddress);
        console.log("pendleWithdrawPT");
        console.log(`lpBalance: ${lpBalance}`);
        console.log(`ptBalance: ${ptBalanceBefore}`);

        // Withdraw PT tokens
        await pendleWithdrawPT(inInfo.market, ptBalanceBefore, user);

        // Check PT balance
        const ptBalanceAfter = await ptContract.balanceOf(userAddress);
        const lpBalanceAfter = await marketContracts.market.balanceOf(userAddress);
        console.log("pendleWithdrawPT");
        console.log(`lpBalance: ${lpBalance} -> ${lpBalanceAfter}`);
        console.log(`ptBalance: ${ptBalanceBefore} -> ${ptBalanceAfter}`);

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

// npx hardhat run  js-scripts/hardhat/USG/scripts/pendle-test.ts
