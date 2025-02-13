import {BaseContext} from "./BaseContext";
import {deploytgUsd} from "../actions/deploytgUsd";
import {MarketContext} from "./MarketContext";
import {OracleContext} from "./OracleContext";
import {UserMarketParams} from "../actions/common";
import {deposit} from "../actions/deposit";
import {borrow} from "../actions/borrow";

import chainViewMarketAccountArtifact from "../../../../artifacts/src/chainview/tgUSD/bot/MarketAccountLiquidationBotInfo.cv.sol/MarketAccountLiquidationBotInfo.json";
import {chainView} from "../../../chainView";
import {parseEther} from "ethers";
import {ConvexCrvLPMarket, ConvexFxnLPMarket} from "../../../../typechain-types";
import {swap} from "../actions/swapCurve";

export type DepositBorrowSpecific = Record<string, Record<string, {deposit: string; borrow: string}>>;

export type LiquidationMarketInfo = {
    maxLTV: bigint;
    liquidationThreshold: bigint;
    collateralUSDPrice: bigint;
    oracleDecimals: bigint;
};
export type LiquidationUserInInfo =   {account: string; market: string}


export type LiquidationAccountInfo = {
    healthRatio: bigint;
    positionDebt: bigint;
    positionValue: bigint;
};

export type LiquidationMarketAccountInfo = {
    markets: LiquidationMarketInfo[];
    accounts: LiquidationAccountInfo[];
};

export class LiquidationContext {
    baseContext?: BaseContext;
    marketContext?: MarketContext;
    oracleContext?: OracleContext;
    userCount: number = 5;
    baseDeposit = 2000;
    marketAddresses: string[] = [];
    userAddresses: string[] = [];
    markets?: (ConvexCrvLPMarket | ConvexFxnLPMarket)[];
    async doDeploy() {
        const {baseContext, marketContext, oracleContext} = await deploytgUsd(this.userCount);
        this.baseContext = baseContext;
        this.marketContext = marketContext;
        this.oracleContext = oracleContext;

        // get data form context
        this.markets = [...Object.values(this.marketContext.convexCrvMarkets), ...Object.values(this.marketContext.convexFxnMarkets)];
        const users = this.baseContext.users;

        // extract the address for process
        this.marketAddresses = await Promise.all(this.markets.map((m) => m.getAddress()));
        this.userAddresses = await Promise.all(users.map((u) => u.getAddress()));
    }

    getSpecificDepositBorrowCase() {
        const specificCases: Record<string, Record<string, {deposit: string; borrow: string}>> = {
            [this.marketAddresses[0]]: {
                [this.userAddresses[0]]: {
                    deposit: "12000",
                    borrow: "9000",
                },
            },
        };
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
                    borrow = Math.max(3000, Number(deposit) / 3).toString();
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
        if (!this.marketAddresses?.length || !this.baseContext) throw new Error("Contracts not depoyed");
        const lpAddress = await Promise.all(this.markets!.map((m) => m.collatToken()));

        const markets = this.markets?.slice(0, 1);
        //TODO add specifics for [0,1] | [1,0] and amounts

        const promises = markets?.map(async (m, i) => {
            swap(this.baseContext!, lpAddress[i], 0, 1, "100");
        });
        await Promise.all(promises || []);
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
        const userAccountsData = await chainView<[string[], LiquidationUserInInfo[]],[LiquidationMarketAccountInfo]>(chainViewMarketAccountArtifact.abi, chainViewMarketAccountArtifact.bytecode, [
            this.marketAddresses, params
        ]);

        const firstAccount = userAccountsData?.at(0)?.accounts?.at(0);
        const firstmarket = userAccountsData?.at(0)?.markets?.at(0);

        const specifics = this.getSpecificDepositBorrowCase();
        const {borrow, deposit} = specifics[this.marketAddresses[0]][this.userAddresses[0]];

        if (firstAccount?.positionDebt !== parseEther(borrow)) {
            throw Error("Specific borrow not applied ");
        }

        if (firstAccount?.positionValue !== (parseEther(deposit) * (firstmarket?.collateralUSDPrice || 0n)) / BigInt(10 ** 18)) {
            throw Error("Specific deposit not applied ");
        }
    }
}
