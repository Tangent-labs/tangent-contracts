import {BaseContext} from "./BaseContext";
import {deploytgUsd} from "../actions/deploytgUsd";
import {MarketContext} from "./MarketContext";
import {OracleContext} from "./OracleContext";
import {UserMarketParams} from "../actions/common";
import {deposit} from "../actions/deposit";
import {borrow} from "../actions/borrow";
import {time} from "@nomicfoundation/hardhat-toolbox/network-helpers";

import chainViewMarketAccountArtifact from "../../../../artifacts/src/chainview/tgUSD/bot/MarketAccountLiquidationBotInfo.cv.sol/MarketAccountLiquidationBotInfo.json";
import {chainView} from "../../../chainView";
import {ConvexCrvLPMarket, ConvexFxnLPMarket} from "../../../../typechain-types";
import {swap} from "../actions/swapCurve";
import {LpDeployContext} from "./LPDeployContext";
import {WStablesContext} from "./WStableContext";

export type DepositBorrowSpecific = Record<string, Record<string, {deposit: string; borrow: string}>>;

export type LiquidationMarketInfo = {
    maxLTV: bigint;
    liquidationThreshold: bigint;
    collateralUSDPrice: bigint;
    oracleDecimals: bigint;
};
export type LiquidationUserInInfo = {account: string; market: string};

export type LiquidationAccountInfo = {
    healthRatio: bigint;
    userDebt: bigint;
    positionValue: bigint;
};

export type LiquidationMarketAccountInfo = {
    markets: LiquidationMarketInfo[];
    accounts: LiquidationAccountInfo[];
};

export class LiquidationContext {
    lpDeployContext?: LpDeployContext;
    wStableContext?: WStablesContext;
    baseContext?: BaseContext;
    marketContext?: MarketContext;
    oracleContext?: OracleContext;
    userCount: number = 10;
    baseDeposit = 2000;
    marketAddresses: string[] = [];
    userAddresses: string[] = [];
    markets?: (ConvexCrvLPMarket | ConvexFxnLPMarket)[];
    fxUSDindex: number = 0;

    async doDeploy() {
        const {baseContext, marketContext, oracleContext, lpDeployContext, wStableContext} = await deploytgUsd(this.userCount);
        this.baseContext = baseContext;
        this.marketContext = marketContext;
        this.oracleContext = oracleContext;
        this.lpDeployContext = lpDeployContext;
        this.wStableContext = wStableContext;

        // get data form context
        this.markets = [...Object.values(this.marketContext.convexCrvMarkets), ...Object.values(this.marketContext.convexFxnMarkets)];
        this.fxUSDindex = 2;
        this.markets = [...Object.values(this.marketContext.convexFxnMarkets)];
        this.fxUSDindex = 0;
        const users = this.baseContext.users;

        // extract the address for process
        this.marketAddresses = await Promise.all(this.markets.map((m) => m.getAddress()));
        this.userAddresses = await Promise.all(users.map((u) => u.getAddress()));
    }

    getSpecificDepositBorrowCase() {
        let i = 0;

        const specificCases = {[this.marketAddresses[this.fxUSDindex]]: {}} as Record<string, Record<string, {deposit: string; borrow: string}>>;
        for (i = 0; i < this.userCount; i++) {
            specificCases[this.marketAddresses[this.fxUSDindex]][this.userAddresses[i]] = {
                deposit: "12000",
                borrow: (10500 - i * 25).toString(),
            };
        }
        console.log(
            Object.values(specificCases)
                .map((o) => o.borrow)
                .join(" / ")
        );
        return specificCases as DepositBorrowSpecific;
    }

    getBorrowAndDepositParams(marketAddresses: string[], userAddresses: string[], specificCases: DepositBorrowSpecific) {
        const depositParams: UserMarketParams = {};
        const borrowParams: UserMarketParams = {};
        marketAddresses.forEach(async (marketaddress) => {
            const currentMarketDeposit: Record<string, string> = {};
            const currentMarketBorrow: Record<string, string> = {};
            userAddresses.forEach((userAddress, userIndex) => {
                let deposit: string;
                let borrow: string;
                // if there is a specific cases we apply it.
                if (specificCases[marketaddress] && specificCases[marketaddress][userAddress]) {
                    deposit = specificCases[marketaddress][userAddress].deposit;
                    borrow = specificCases[marketaddress][userAddress].borrow;
                } else {
                    // default case a low risk loan
                    deposit = (3000 + this.baseDeposit * (userIndex + 1)).toString();
                    borrow = Math.max(3000, Number(deposit) / 2).toString();
                }
                currentMarketDeposit[userAddress] = deposit;
                currentMarketBorrow[userAddress] = borrow;
            });
            depositParams[marketaddress] = currentMarketDeposit;
            borrowParams[marketaddress] = currentMarketBorrow;
        });
        return {depositParams, borrowParams};
    }

    async doDepositAndBorrow() {
        if (!this.marketAddresses?.length || !this.userAddresses?.length || !this.baseContext) throw new Error("Contracts not depoyed");

        // generate the params
        const specificCases = this.getSpecificDepositBorrowCase();
        const {depositParams, borrowParams}: {depositParams: UserMarketParams; borrowParams: UserMarketParams} = this.getBorrowAndDepositParams(
            this.marketAddresses,
            this.userAddresses,
            specificCases
        );

        // let's do it .
        await deposit(this.baseContext, depositParams);
        await borrow(this.baseContext, borrowParams);
    }

    async unbalanceContext() {
        const amount = 4_300_000;

        if (!this.marketAddresses?.length || !this.baseContext) throw new Error("Contracts not depoyed");

        const toSwapMarketIndex = this.fxUSDindex; // others markets are link to chainlink so swap dosen't have an effect on price.
        const lpAddress = await this.markets![toSwapMarketIndex].collatToken();
        await swap(this.baseContext!.users[0], lpAddress, 1, 0, amount.toString());

        // Time advance
        const day = 1;
        const seconds = day * 24 * 60 * 60;
        await time.increase(seconds);
        console.info("\x1b[32m%s\x1b[0m", "Time has been incresed by " + day + " day on the test node !");
    }

    async testChainView() {
        // just to test the accounts chain view execution
        const params = this.marketAddresses
            .map((marketAddress) =>
                this.userAddresses.map((userAddress) => {
                    return {
                        account: userAddress,
                        market: marketAddress,
                    };
                })
            )
            .flat();

        // test the full chain view
        const userAccountsData = await chainView<[string[], LiquidationUserInInfo[]], [LiquidationMarketAccountInfo]>(
            chainViewMarketAccountArtifact.abi,
            chainViewMarketAccountArtifact.bytecode,
            [this.marketAddresses, params]
        );

        const firstAccount = userAccountsData?.at(0)?.accounts?.at(0);
        const firstmarket = userAccountsData?.at(0)?.markets?.at(0);

        const specifics = this.getSpecificDepositBorrowCase();
        const {borrow, deposit} = specifics[this.marketAddresses[0]][this.userAddresses[0]];

        if (firstAccount?.userDebt !== parseEther(borrow)) {
            throw Error("Specific borrow not applied ");
        }

        if (firstAccount?.positionValue !== (parseEther(deposit) * (firstmarket?.collateralUSDPrice || 0n)) / BigInt(10 ** 18)) {
            throw Error("Specific deposit not applied ");
        }
    }
}
