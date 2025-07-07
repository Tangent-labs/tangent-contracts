import {BaseContext, createJSONAddress} from "./BaseContext";
import {deployUSG} from "../actions/deployUSG";
import {MarketContext} from "./MarketContext";
import {OracleContext} from "./OracleContext";
import {UserMarketParams} from "../actions/common";
import {deposit} from "../actions/deposit";
import {borrow} from "../actions/borrow";
import {time} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import * as fs from "fs";

import chainViewMarketAccountArtifact from "../../../../artifacts/src/chainview/USG/bot/MarketAccountLiquidationBotInfo.cv.sol/MarketAccountLiquidationBotInfo.json";
import {chainView} from "../../../chainView";
import {ConvexCrvLPMarket, ConvexFxnLPMarket} from "../../../../typechain-types";
import {swap} from "../actions/swapCurve";
import {LpDeployContext} from "./LPDeployContext";
import {WStablesContext} from "./WStableContext";
import {parseEther} from "ethers";

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
    userCount: number = 5;
    baseDeposit = 2000;
    marketAddresses: string[] = [];
    userAddresses: string[] = [];
    markets?: (ConvexCrvLPMarket | ConvexFxnLPMarket)[];
    fxUSDindex: number = 0;

    async doDeploy() {
        const {baseContext, marketContext, oracleContext, lpDeployContext, wStableContext} = await deployUSG(this.userCount);
        this.baseContext = baseContext;
        this.marketContext = marketContext;
        this.oracleContext = oracleContext;
        this.lpDeployContext = lpDeployContext;
        this.wStableContext = wStableContext;

        this.markets = [...Object.values(this.marketContext.convexFxnMarkets)];

        this.fxUSDindex = 0;
        const users = this.baseContext.users;

        // extract the address for process
        this.marketAddresses = await Promise.all(this.markets.map((m) => m.getAddress()));
        this.userAddresses = await Promise.all(users.map((u) => u.getAddress()));
        fs.writeFileSync("../addresses.json", JSON.stringify(await createJSONAddress(baseContext, marketContext, oracleContext, lpDeployContext, wStableContext)));
    }

    getSpecificDepositBorrowCase() {
        let i = 0;

        const specificCases = {[this.marketAddresses[this.fxUSDindex]]: {}} as Record<string, Record<string, {deposit: string; borrow: string}>>;
        for (i = 0; i < this.userCount; i++) {
            specificCases[this.marketAddresses[this.fxUSDindex]][this.userAddresses[i]] = {
                deposit: "12000",
                borrow: (9000 - i * 25).toString(),
            };
        }

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
                    borrow = Math.max(4000, Number(deposit) / 3).toString();
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
        const amount = 450_000;

        const USG_USDC = this.lpDeployContext?.stableLp["USG-USDC"];
        const USG_wfrxUSD = this.lpDeployContext?.stableLp["USG-wfrxUSD"];

        if (!this.marketAddresses?.length || !this.baseContext) throw new Error("Contracts not depoyed");

        await swap(this.baseContext!.users[4], await USG_USDC!.getAddress(), 1, 0, amount.toString());
        await swap(this.baseContext!.users[4], await USG_wfrxUSD!.getAddress(), 1, 0, amount.toString());

        await time.increase(30 * 60 * 60);

        // Deposit on all markets to checkpoint the IR
        const depositParams: UserMarketParams = {};
        this.marketAddresses.forEach((marketAddress) => {
            depositParams[marketAddress] = {
                [this.userAddresses[0]]: "1000",
            };
        });
        await deposit(this.baseContext, depositParams);

        // Time advance
        const day = 100;
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

        const expectedBorrow = parseEther(borrow);
        const borrowTolerance = expectedBorrow / 100n;
        if (firstAccount?.userDebt === undefined || firstAccount.userDebt < expectedBorrow - borrowTolerance || firstAccount.userDebt > expectedBorrow + borrowTolerance) {
            throw Error("Specific borrow not applied within 1% tolerance, expected " + expectedBorrow + " got " + firstAccount?.userDebt);
        }

        const expectedPositionValue = (parseEther(deposit) * (firstmarket?.collateralUSDPrice || 0n)) / BigInt(10 ** 18);
        const positionTolerance = expectedPositionValue / 100n;
        if (
            firstAccount?.positionValue === undefined ||
            firstAccount.positionValue < expectedPositionValue - positionTolerance ||
            firstAccount.positionValue > expectedPositionValue + positionTolerance
        ) {
            throw Error("Specific deposit not applied within 1% tolerance");
        }
    }
}
