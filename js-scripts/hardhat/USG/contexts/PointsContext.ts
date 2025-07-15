import {ethers} from "hardhat";
import {giveTokensToAddresses} from "../../thief";
import {TOKENS_TO_GIVE} from "../../tokensToGive.config";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {time} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import {CURVE_CONTEXT} from "defi-resources/build/ressources/mappings/curveContext";
import {executeGeneratedActions} from "../scripts/campaignActions";
import {CurveLpKey} from "../actions/depositCurveLP";

export class PointsContext {
    user1: HardhatEthersSigner | null = null;
    user2: HardhatEthersSigner | null = null;

    constructor() {}

    async initUsers(): Promise<void> {
        try {
            const signers = await ethers.getSigners();

            this.user1 = signers[0];
            this.user2 = signers[1];

            await giveTokensToAddresses([this.user1, this.user2], TOKENS_TO_GIVE(10000000));
            console.log(`Distributed tokens to ${this.user1.address} and ${this.user2.address}`);
        } catch (error) {
            console.error("Error in initUsers:", error);
            throw error;
        }
    }

    async advanceTime(days: number): Promise<void> {
        try {
            const seconds = Number(days) * 86400;
            await time.increase(seconds);
            console.log(`Advanced blockchain time by ${days} days`);
        } catch (error) {
            console.error("Error in advanceTime:", error);
            throw error;
        }
    }

    async transferStakeDaoGauge(lpKey: CurveLpKey, fromUser: HardhatEthersSigner, toAddress: string, amount: bigint): Promise<void> {
        const context = CURVE_CONTEXT[lpKey];

        try {
            const tokenContract = new ethers.Contract(context.stakeDaoGauge, ["function transfer(address to, uint256 amount) external returns (bool)"], fromUser);
            const tx = await tokenContract.transfer(toAddress, amount);
            await tx.wait();
        } catch (error) {
            console.error("Error in transferPosition:", error);
            throw error;
        }
    }

    async transferCurveGauge(lpKey: CurveLpKey, fromUser: HardhatEthersSigner, toAddress: string, amount: bigint): Promise<void> {
        const context = CURVE_CONTEXT[lpKey];

        try {
            const tokenContract = new ethers.Contract(context.curveGauge, ["function transfer(address to, uint256 amount) external returns (bool)"], fromUser);
            const tx = await tokenContract.transfer(toAddress, amount);
            await tx.wait();
        } catch (error) {
            console.error("Error in transferPosition:", error);
            throw error;
        }
    }

    async transferCurveLP(lpKey: CurveLpKey, fromUser: HardhatEthersSigner, toAddress: string, amount: bigint): Promise<void> {
        const context = CURVE_CONTEXT[lpKey];

        try {
            const tokenContract = new ethers.Contract(context.curveLp, ["function transfer(address to, uint256 amount) external returns (bool)"], fromUser);
            const tx = await tokenContract.transfer(toAddress, amount);
            await tx.wait();
        } catch (error) {
            console.error("Error in transferPosition:", error);
            throw error;
        }
    }

    async curveDeposit(): Promise<void> {
        try {
            await executeGeneratedActions(this);
        } catch (error) {
            console.error("Error in curveDeposit:", error);
            throw error;
        }
    }
}
