import {time} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import {ethers} from "hardhat";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {depositOnCurveStableLp} from "../actions/depositOnCurveStableLp";
import {depositOnCurveGauge} from "../actions/depositOnCurveGauge";
import {withdrawOnCurveGauge} from "../actions/withdrawOnCurveGauge";
import {depositStakeDao} from "../actions/depositStakeDao";
import {depositLlamaLend} from "../actions/depositLlamaLend";
import {giveTokensToAddresses} from "../../thief";
import {TOKENS_TO_GIVE} from "../../tokensToGive.config";
import {CRV_DUO_USDC_crvUSD, CRV_DUO_USDe_USDC, CRV_DUO_USDT_crvUSD} from "defi-resources/build/ressources/lps/curve";
import {SDT_crvUSD_USDC_STRAT, SDT_crvUSD_USDT_GAUGE, SDT_crvUSD_USDT_STRAT} from "defi-resources/build/ressources/erc20/stakeDao";
import {crvUSD} from "defi-resources/build/ressources/erc20/common";
import {withdrawStakeDao} from "../actions/withdrawStakeDao";
import {removeLiquidityOnCurveStableLp} from "../actions/removeLiquidityOnCurveStableLp";

export class PointsContext {
    private user1: HardhatEthersSigner | null = null;
    private user2: HardhatEthersSigner | null = null;

    constructor() {}

    async initUsers(): Promise<void> {
        try {
            // Get two signers from Hardhat
            const signers = await ethers.getSigners();
            if (signers.length < 2) {
                throw new Error("Not enough signers available");
            }
            this.user1 = signers[0];
            this.user2 = signers[1];

            // Distribute tokens to users
            await giveTokensToAddresses([this.user1, this.user2], TOKENS_TO_GIVE(10000));
            console.log(`Distributed tokens to ${this.user1.address} and ${this.user2.address}`);
        } catch (error) {
            console.error("Error in initUsers:", error);
            throw error;
        }
    }

    async advanceTime(days: number): Promise<void> {
        try {
            const seconds = Number(days!) * 86400;
            await time.increase(seconds);
            console.log(`Advanced blockchain time by ${days} days`);
        } catch (error) {
            console.error("Error in advanceTime:", error);
            throw error;
        }
    }

    async transferPosition(tokenAddress: string, fromUser: HardhatEthersSigner, toAddress: string, amount: bigint): Promise<void> {
        try {
            const tokenContract = new ethers.Contract(tokenAddress, ["function transfer(address to, uint256 amount) external returns (bool)"], fromUser);
            const tx = await tokenContract.transfer(toAddress, amount);
            await tx.wait();
            console.log(`Transferred ${amount} tokens from ${fromUser.address} to ${toAddress}`);
        } catch (error) {
            console.error("Error in transferPosition:", error);
            throw error;
        }
    }

    async curveDeposit(): Promise<void> {
        try {
            if (!this.user1 || !this.user2) {
                throw new Error("Users not initialized. Call initUsers first.");
            }

            // Day 1: User1 deposits and stakes
            const user1 = this.user1;
            const USDeUSDC = await depositOnCurveStableLp(CRV_DUO_USDe_USDC, 10000, 10n ** 20n, 100000000n, user1);
            console.log(`User1 deposited on Curve USDe/USDC`);

            await depositOnCurveGauge("0x04E80Db3f84873e4132B221831af1045D27f140F", USDeUSDC, user1, 10000000n);
            console.log(`User1 staked on Curve Gauge`);

            // Advance time by 12 days
            await this.advanceTime(12);

            // Day 8: User1 withdraws from gauge and transfers LP to User2
            await withdrawOnCurveGauge("0x04E80Db3f84873e4132B221831af1045D27f140F", user1, 1000000n);
            console.log(`User1 withdrew from Curve Gauge`);

            await this.transferPosition(CRV_DUO_USDe_USDC, user1, this.user2.address, 5000000n);

            // Day 8: User1 deposits to another Curve pool and StakeDao
            const crvUSDUSDC = await depositOnCurveStableLp(CRV_DUO_USDC_crvUSD, 10000, 1000000n, 10n ** 19n, user1);
            console.log(`User1 deposited on Curve USDC/crvUSD`);

            await depositStakeDao(crvUSDUSDC, SDT_crvUSD_USDC_STRAT, user1, 1000000n);
            console.log(`User1 deposited on StakeDao`);

            // Advance time by 30 days
            await this.advanceTime(30);

            // Day 22: User2 deposits, stakes, and withdraws
            const user2 = this.user2;

            const USDT_USDC = await depositOnCurveStableLp(CRV_DUO_USDT_crvUSD, 100000, 100000000n, 100000000n, user2);
            console.log(`User2 deposited on Curve USDT/crvUSD`);

            await depositStakeDao(USDT_USDC, SDT_crvUSD_USDT_STRAT, user2, 10000000000000000000n);
            console.log(`User2 deposited on StakeDao`);

            await withdrawStakeDao(SDT_crvUSD_USDT_STRAT, user2, 500000n);
            console.log(`User2 withdrew from StakeDao`);

            // User2 transfers StakeDao position to another address (e.g., User1)
            await this.transferPosition(SDT_crvUSD_USDT_GAUGE, user2, user1.address, 10000n);
            console.log("User2 transferred gauge tokens to user 1");

            // User2 deposits to LlamaLend
            await depositLlamaLend("0xff467c6e827ebbea64da1ab0425021e6c89fbe0d", crvUSD, user2, 10000, 1000000n);
            console.log(`User2 deposited on LlamaLend`);

            // Advance time by 30 days
            await this.advanceTime(30);

            const stakeVault = await ethers.getContractAt("IStakeDaoVault", SDT_crvUSD_USDT_STRAT);
            const gaugeAddress = await stakeVault.liquidityGauge();
            const gauge = await ethers.getContractAt("ISdtLiquidityGauge", gaugeAddress, user2);
            const gaugeBalance = await gauge.balanceOf(user2);

            await withdrawStakeDao(SDT_crvUSD_USDT_STRAT, user2, gaugeBalance);
            console.log("User2 withdrawn all funds on Stake Gauge");

            const lpBalance = await USDT_USDC.balanceOf(user2);

            await removeLiquidityOnCurveStableLp(CRV_DUO_USDT_crvUSD, lpBalance, user2);
            console.log("User2 withdrawn all funds on CRV_DUO_USDT_crvUSD lp");
        } catch (error) {
            console.error("Error in curveDeposit:", error);
            throw error;
        }
    }

    getUser1(): HardhatEthersSigner | null {
        return this.user1;
    }

    getUser2(): HardhatEthersSigner | null {
        return this.user2;
    }
}
