import {ethers} from "hardhat";
import {depositOnCurveStableLp} from "../actions/depositOnCurveStableLp";
import {depositOnCurveGauge} from "../actions/depositOnCurveGauge";
import {withdrawOnCurveGauge} from "../actions/withdrawOnCurveGauge";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {giveTokensToAddresses} from "../../thief";
import {TOKENS_TO_GIVE} from "../../tokensToGive.config";
import {depositStakeDao} from "../actions/depositStakeDao";
import {CRV_DUO_USDC_crvUSD, CRV_DUO_USDe_USDC, CRV_DUO_USDT_crvUSD} from "defi-resources/build/ressources/lps/curve";
import {SDT_crvUSD_USDC_STRAT, SDT_crvUSD_USDT_STRAT} from "defi-resources/build/ressources/erc20/stakeDao";
import {depositLlamaLend} from "../actions/depositLlamaLend";
import {crvUSD} from "defi-resources/build/ressources/erc20/common";

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

            // Get Token on User0
            await giveTokensToAddresses([this.user1], TOKENS_TO_GIVE(10000));
            await giveTokensToAddresses([this.user2], TOKENS_TO_GIVE(10000));
        } catch (error) {
            console.error("Error in initUsers:", error);
            throw error;
        }
    }

    async curveDeposit(): Promise<void> {
        try {
            if (!this.user1 || !this.user2) {
                throw new Error("Users not initialized. Call initUsers first.");
            }

            const user = this.user1;

            const USDeUSDC = await depositOnCurveStableLp(CRV_DUO_USDe_USDC, 10000, 10n ** 20n, 100000000n, user);

            // next use CURVE_USDe_USDC_GAUGE const
            await depositOnCurveGauge("0x04E80Db3f84873e4132B221831af1045D27f140F", USDeUSDC, user, 10000000n);

            await withdrawOnCurveGauge("0x04E80Db3f84873e4132B221831af1045D27f140F", user, 1000000n);

            const crvUSDUSDC = await depositOnCurveStableLp(CRV_DUO_USDC_crvUSD, 10000, 1000000n, 10n ** 19n, user);

            await depositStakeDao(crvUSDUSDC, SDT_crvUSD_USDC_STRAT, user, 1000000n);

            const user2 = this.user2;

            const USDTcrvUSD = await depositOnCurveStableLp(CRV_DUO_USDT_crvUSD, 10000, 100000000n, 10n ** 20n, user2);

            await depositStakeDao(USDTcrvUSD, SDT_crvUSD_USDT_STRAT, user2, 10000000n);

            await depositLlamaLend("0xff467c6e827ebbea64da1ab0425021e6c89fbe0d", crvUSD, user2, 10000, 1000000n);
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
