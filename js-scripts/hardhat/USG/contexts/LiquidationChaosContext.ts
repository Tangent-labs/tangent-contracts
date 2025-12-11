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

/**
 * Helper function to generate a random number between min and max (inclusive)
 */
function randomBetween(min: number, max: number): number {
    return Math.random() * (max - min) + min;
}

/**
 * Helper function to generate a random bigint between min and max (inclusive)
 */
function randomBigIntBetween(min: bigint, max: bigint): bigint {
    const range = max - min;
    const random = BigInt(Math.floor(Math.random() * Number(range)));
    return min + random;
}

export class LiquidationChaosContext {
    lpDeployContext?: LpDeployContext;
    wStableContext?: WStablesContext;
    baseContext?: BaseContext;
    marketContext?: MarketContext;
    oracleContext?: OracleContext;
    mockOracle?: MockOracle;
    userCount: number = 300;
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
        // Use all users for chaos mode
        const users = this.baseContext.users;

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
        // Reduce the price (chaos mode: call minus to trigger liquidations)
        await mockOracle.minus();

        // Set the mock oracle to the market
        await market.setCollatOracle(mockOracleAddress);

        console.log("setOracleToMock (chaos)", marketAddress, mockOracleAddress);
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

        // Minimum borrow amount: 1000 USG (in wei)
        const MIN_BORROW_USG = 1000n * 10n ** 18n;
        // Minimum deposit to ensure we can borrow at least 1000 USG even at 20% LTV
        // If borrow = 20% of position value and borrow >= 1000 USG
        // Then position value >= 1000 / 0.2 = 5000 USD
        const MIN_DEPOSIT_USD = 5_000n;

        for (const marketaddress of marketAddresses) {
            const currentMarketDeposit: Record<string, string> = {};
            const currentMarketBorrow: Record<string, string> = {};
            for (let userIndex = 0; userIndex < userAddresses.length; userIndex++) {
                const userAddress = userAddresses[userIndex];
                let deposit: string;
                const marketInfo = await this.getMarketInfo(marketaddress);

                const PRICE = marketInfo.collateralPrice;
                const DECIMALS = marketInfo.collatDecimals;

                // Generate random position value between MIN_DEPOSIT_USD and 100,000 USD
                // This ensures we can always borrow at least 1000 USG even at 20% LTV
                const minUSD = MIN_DEPOSIT_USD;
                const maxUSD = 100_000n;
                const USD = randomBigIntBetween(minUSD, maxUSD);

                // we deposit the equivalent of USD amount in collateral
                const positionValue = (USD * 10n ** DECIMALS * 10n ** 18n + PRICE - 1n) / PRICE;
                deposit = positionValue.toString();

                currentMarketDeposit[userAddress] = formatEther(deposit);

                // Generate random borrow percentage between 20% and 50% of position value
                const borrowPercentage = randomBetween(0.2, 0.5);
                let borrowAmountUSD = (USD * BigInt(Math.floor(borrowPercentage * 10000))) / 10000n;

                // Convert to wei for comparison
                let borrowAmountWei = borrowAmountUSD * 10n ** 18n;

                // Ensure minimum borrow of 1000 USG
                if (borrowAmountWei < MIN_BORROW_USG) {
                    borrowAmountWei = MIN_BORROW_USG;
                    borrowAmountUSD = MIN_BORROW_USG / 10n ** 18n;
                }

                // Convert borrow amount to string (in USG/USD terms, parseEther will handle the decimals)
                currentMarketBorrow[userAddress] = formatEther(borrowAmountWei);
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
