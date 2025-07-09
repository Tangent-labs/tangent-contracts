import {ethers} from "hardhat";
import {getPendleMarketContracts, pendleDepositLP, pendleDepositYT, pendleWithdrawLP, pendleDepositPT} from "../actions/pendleActions";

import {Signer} from "ethers";

type InInfo = {
    token: string;
    amount: bigint;
    market: string;
    underlying: string;
};

const main = async (inInfo: InInfo) => {
    let lpBalance = 0n;
    const user = (await ethers.getSigners())[0] as unknown as Signer;

    const marketContracts = await getPendleMarketContracts(inInfo.market);
    const marketContract = marketContracts.market;
    const userAddress = await user.getAddress();

    // Deposit the underlying into the market
    try {
        await pendleDepositLP(inInfo.market, inInfo.underlying, inInfo.amount, user);
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
        await pendleWithdrawLP(inInfo.market, inInfo.underlying, lpBalance, user);
        lpBalance = await marketContract.balanceOf(userAddress);

        if (lpBalance > 0n) {
            throw new Error("still have LP tokens after withdraw");
        }
    } catch (error) {
        console.error("Error during Pendle withdraw:", error);
        throw error;
    }

    try {
        await pendleDepositYT(inInfo.market, inInfo.underlying, inInfo.amount, user);
    } catch (error) {
        console.error("Error during Pendle deposit with YT retention:", error);
        throw error;
    }

    try {
        lpBalance = await marketContract.balanceOf(userAddress);
        await pendleDepositPT(inInfo.market, lpBalance, 0n, user);
        // ptBalance
        const ptContract = marketContracts.pt;
        const ptBalance = await ptContract.balanceOf(userAddress);
        if (ptBalance === 0n) {
            throw new Error("no PT tokens after withdraw");
        }
    } catch (error) {
        console.error("Error during Pendle withdraw single PT:", error);
        throw error;
    }
    console.log("Pendle test passed");
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

// npx hardhat run  js-scripts/hardhat/USG/scripts/pendle-test.ts
