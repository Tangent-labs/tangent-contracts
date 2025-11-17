import {BaseContext, createJSONAddress} from "./BaseContext";
import {deployUSG} from "../actions/deployUSG";
import {MarketContext} from "./MarketContext";
import {OracleContext} from "./OracleContext";
import {loadAddresses, UserMarketParams} from "../actions/common";
import {deposit} from "../actions/deposit";
import {borrow} from "../actions/borrow";
import {time} from "@nomicfoundation/hardhat-toolbox/network-helpers";

import {ethers} from "hardhat";

import chainViewMarketAccountArtifact from "../../../../artifacts/src/chainview/USG/bot/MarketAccountLiquidationBotInfo.cv.sol/MarketAccountLiquidationBotInfo.json";
import {chainView} from "../../../chainView";
import {BasicERC20Market, ConvexCrvLPMarket, ConvexFxnLPMarket} from "../../../../typechain-types";
import {MockOracle} from "../../../../typechain-types";
import {swap} from "../actions/swapCurve";
import {LpDeployContext} from "./LPDeployContext";
import {WStablesContext} from "./WStableContext";
import {formatEther} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";

export type DepositBorrowSpecific = Record<string, Record<string, {deposit: string; borrow: string}>>;

export type LiquidationMarketInfo = {
    toObject: () => LiquidationMarketInfo;
    maxLTV: bigint;
    liquidationThreshold: bigint;
    collateralUSDPrice: bigint;
    oracleDecimals: bigint;
    market: string;
};
export type LiquidationUserInInfo = {account: string; market: string};

export type LiquidationAccountInfo = {
    toObject: () => LiquidationAccountInfo;
    healthRatio: bigint;
    userDebt: bigint;
    positionValue: bigint;
};

export type LiquidationMarketAccountInfo = {
    markets: LiquidationMarketInfo[];
    accounts: LiquidationAccountInfo[];
};

export type MarketInfo = {
    collatName: string;
    marketAddress: string;
    maxLTV: bigint;
    liquidationThreshold: bigint;
    collateralPrice: bigint;
    collatDecimals: bigint;
};

export class LiquidationContext {
    lpDeployContext?: LpDeployContext;
    wStableContext?: WStablesContext;
    baseContext?: BaseContext;
    marketContext?: MarketContext;
    oracleContext?: OracleContext;
    mockOracle?: MockOracle;
    userCount: number = 5;
    baseDeposit = 2000;
    marketAddresses: string[] = [];
    userAddresses: string[] = [];
    markets?: (ConvexCrvLPMarket | ConvexFxnLPMarket | BasicERC20Market)[];
    fxUSDindex: number = 0;
    jsonAddressData?: any;
    marketInfo: Record<string, MarketInfo> = {};
    mockOracles: Record<string, MockOracle> = {};

    async doDeploy() {
        const {baseContext, marketContext, oracleContext, lpDeployContext, wStableContext} = await deployUSG(this.userCount);
        this.baseContext = baseContext;
        this.marketContext = marketContext;
        this.oracleContext = oracleContext;
        this.lpDeployContext = lpDeployContext;
        this.wStableContext = wStableContext;

        this.markets = [
            ...Object.values(this.marketContext.convexFxnMarkets),
            ...Object.values(this.marketContext.convexCrvMarkets),
            ...Object.values(this.marketContext.pendlePTMarkets),
        ];

        this.fxUSDindex = 0;
        const users = this.baseContext.users.slice(0, 2);

        // extract the address for process
        this.marketAddresses = await Promise.all(this.markets.map((m) => m.getAddress()));
        this.userAddresses = await Promise.all(users.map((u) => u.getAddress()));
        // Store the JSON data for later use by the script
        this.jsonAddressData = await createJSONAddress(baseContext, marketContext, oracleContext, lpDeployContext, wStableContext);
    }

    async getMarketInfo(marketAddress: string) {
        if (this.marketInfo[marketAddress]) {
            return this.marketInfo[marketAddress];
        }

        const addresses = loadAddresses();
        const market = await ethers.getContractAt("MarketExternalActions", marketAddress);
        const oracleAdress = await market.collatOracle();
        const collatTokenAddress = await market.collatToken();
        const collatToken = await ethers.getContractAt("IERC20Metadata", collatTokenAddress);
        const collatDecimals = await collatToken.decimals();
        const oracle = await ethers.getContractAt("IPriceOracle", oracleAdress);
        const collateralPrice = await oracle.latestAnswer(true);
        const maxLTV = await market.maxLTV();
        const liquidationThreshold = await market.liquidationThreshold();

        const collatName = addresses?.markets?.find((m: any) => m.marketAddress.toLowerCase() === marketAddress.toLowerCase())?.collatName;
        const data: MarketInfo = {
            collatName,
            maxLTV: maxLTV,
            liquidationThreshold: liquidationThreshold,
            collateralPrice: collateralPrice,
            marketAddress,
            collatDecimals,
        };
        this.marketInfo[marketAddress] = data;
        return data;
    }

    async setOracleToMock(marketAddress: string) {
        const market = await ethers.getContractAt("MarketExternalActions", marketAddress);
        // Get lastprice from the oracle
        const oracle = await ethers.getContractAt("IPriceOracle", await market.collatOracle());
        const lastPrice = await oracle.latestAnswer(true);

        // Deploy the mock oracle
        const mockOracle = await ethers.deployContract("MockOracle");
        const mockOracleAddress = await mockOracle.getAddress();
        await mockOracle.setLastAnswer(lastPrice);
        // Reduce the price
        await mockOracle.minus();

        // Set the mock oracle to the market
        await market.setCollatOracle(mockOracleAddress);

        console.log("setOracleToMock", marketAddress, mockOracleAddress);
        this.mockOracles[marketAddress] = mockOracle;
    }

    async setOraclesToMock() {
        for (const market of Object.values(this.marketContext?.convexCrvMarkets || {})) {
            await this.setOracleToMock(await market.getAddress());
        }
        for (const market of Object.values(this.marketContext?.convexFxnMarkets || {})) {
            await this.setOracleToMock(await market.getAddress());
        }
        for (const market of Object.values(this.marketContext?.pendlePTMarkets || {})) {
            await this.setOracleToMock(await market.getAddress());
        }
    }

    async getBorrowAndDepositParams(marketAddresses: string[], userAddresses: string[]) {
        const depositParams: UserMarketParams = {};
        const borrowParams: UserMarketParams = {};
        for (const marketaddress of marketAddresses) {
            const currentMarketDeposit: Record<string, string> = {};
            const currentMarketBorrow: Record<string, string> = {};
            for (let userIndex = 0; userIndex < userAddresses.length; userIndex++) {
                const userAddress = userAddresses[userIndex];
                let deposit: string;
                const marketInfo = await this.getMarketInfo(marketaddress);

                const USD = 10_000n;
                const PRICE = marketInfo.collateralPrice; 
                const DECIMALS = marketInfo.collatDecimals; 
                // we deposit the equivalent of 10_000 USD in collateral
                const position10000Value = (USD * 10n ** DECIMALS * 10n ** 18n + PRICE - 1n) / PRICE;
                deposit = position10000Value.toString();

                currentMarketDeposit[userAddress] = formatEther(deposit);
                // borrow 6800 for liquidate & 8500 for  seizing
                currentMarketBorrow[userAddress] = userIndex % 2 === 0 ? "6800" : "8500";
            }
            depositParams[marketaddress] = currentMarketDeposit;
            borrowParams[marketaddress] = currentMarketBorrow;
        }
        return {depositParams, borrowParams};
    }

    async doDepositAndBorrow() {
        if (!this.marketAddresses?.length || !this.userAddresses?.length || !this.baseContext) throw new Error("Contracts not depoyed");

        // generate the params

        const {depositParams, borrowParams}: {depositParams: UserMarketParams; borrowParams: UserMarketParams} = await this.getBorrowAndDepositParams(
            this.marketAddresses,
            this.userAddresses
        );
        const users = await Promise.all(this.baseContext?.users.filter(async (u) => this.userAddresses.includes(await u.getAddress())));

        // // let's do it .
        await deposit(users as HardhatEthersSigner[], depositParams);
        await borrow(users as HardhatEthersSigner[], borrowParams);
    }
}
