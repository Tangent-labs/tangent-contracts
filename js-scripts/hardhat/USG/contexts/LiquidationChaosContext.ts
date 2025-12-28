import {ethers} from "hardhat";
import {formatEther} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import * as fs from "fs";
import * as path from "path";

import {BaseContext, createJSONAddress} from "./BaseContext";
import {MarketContext} from "./MarketContext";
import {OracleContext} from "./OracleContext";
import {LpDeployContext} from "./LPDeployContext";
import {WStablesContext} from "./WStableContext";

import {deployUSG} from "../actions/deployUSG";
import {loadAddresses, UserMarketParams} from "../actions/common";
import {deposit} from "../actions/deposit";
import {borrow} from "../actions/borrow";

import {MockOracle} from "../../../../typechain-types";

// ============================================================================
// CONFIGURATION
// ============================================================================

const CONFIG = {
    USER_COUNT: 5,
    MAX_POSITION_COUNT: 300,
    INITIAL_USG_SUPPLY: 1_000_000,

    MIN_BORROW_USG: 1000n * 10n ** 18n,

    // Position size distribution (USD)
    POSITION_SIZE: {
        SMALL: {value: 5_000n, probability: 0.8},
        MEDIUM: {min: 5_000n, max: 10_000n, probability: 0.1},
        LARGE: {min: 14_000n, max: 20_000n, probability: 0.1},
    },

    // Position type distribution (LTV ranges)
    POSITION_TYPES: {
        SAFE: {ltvRange: [0.3, 0.4], probability: 0.1},
        LIQUIDATABLE: {ltvRange: [0.62, 0.65], probability: 0.8},
        SEIZABLE: {ltvRange: [0.75, 0.85], probability: 0.1},
    },

    ORACLE_PRICE_DROP_PERCENT: 66n,
    DEBT_SAFETY_MARGIN_PERCENT: 5n,
    SKIP_USER_PROBABILITY: 0.2,
} as const;

const EXCLUDED_MARKETS = [
    "frxUSD-USDe",
    "pxETH-WETH",
    "pxETH-stETH",
    "frxETH-WETH",
    "USR-RLP",
    "cbBTC-WBTC",
    "crvUSD-ETH-CRV",
    "CVX-ETH",
    "GHO-cbBTC-WETH",
    "USDC-WBTC-WETH",
    "USDT-WBTC-WETH",
    "USDe 27/11/25",
    "sUSDe 27/11/25",
] as const;

// ============================================================================
// TYPES
// ============================================================================

export type MarketInfo = {
    collatName: string;
    marketAddress: string;
    maxLTV: bigint;
    liquidationThreshold: bigint;
    collateralPrice: bigint;
    collatDecimals: bigint;
    maxMarketDebt: bigint;
    minimumLoan: bigint;
};

type MarketLimits = {
    maxMarketDebt: bigint;
    minimumLoan: bigint;
    initialTotalDebt: bigint;
    effectiveMaxDebt: bigint;
};

type PositionIntent = "safe" | "liquidatable" | "seizable";

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

function randomBetween(min: number, max: number): number {
    return Math.random() * (max - min) + min;
}

function randomBigIntBetween(min: bigint, max: bigint): bigint {
    if (min === max) return min;
    const range = max - min;
    return min + BigInt(Math.floor(Math.random() * Number(range)));
}

function getRandomPositionSizeUSD(): bigint {
    const rand = Math.random();
    const {SMALL, MEDIUM, LARGE} = CONFIG.POSITION_SIZE;

    if (rand < SMALL.probability) {
        return SMALL.value;
    }
    if (rand < SMALL.probability + MEDIUM.probability) {
        return randomBigIntBetween(MEDIUM.min, MEDIUM.max);
    }
    return randomBigIntBetween(LARGE.min, LARGE.max);
}

function getRandomPositionType(): {intent: PositionIntent; borrowPercentage: number} {
    const rand = Math.random();
    const {SAFE, LIQUIDATABLE, SEIZABLE} = CONFIG.POSITION_TYPES;

    if (rand < SAFE.probability) {
        return {
            intent: "safe",
            borrowPercentage: randomBetween(SAFE.ltvRange[0], SAFE.ltvRange[1]),
        };
    }
    if (rand < SAFE.probability + LIQUIDATABLE.probability) {
        return {
            intent: "liquidatable",
            borrowPercentage: randomBetween(LIQUIDATABLE.ltvRange[0], LIQUIDATABLE.ltvRange[1]),
        };
    }
    return {
        intent: "seizable",
        borrowPercentage: randomBetween(SEIZABLE.ltvRange[0], SEIZABLE.ltvRange[1]),
    };
}

function getExcludedAddresses(): string[] {
    const addresses = loadAddresses();
    return EXCLUDED_MARKETS.map((name) => addresses.markets.find((m: {collatName: string}) => m.collatName === name)?.marketAddress).filter(Boolean);
}

// ============================================================================
// MAIN CLASS
// ============================================================================

export class LiquidationChaosContext {
    // Contexts
    lpDeployContext?: LpDeployContext;
    wStableContext?: WStablesContext;
    baseContext?: BaseContext;
    marketContext?: MarketContext;
    oracleContext?: OracleContext;

    // State
    marketAddresses: string[] = [];
    userAddresses: string[] = [];
    marketInfoCache: Record<string, MarketInfo> = {};
    mockOracles: Record<string, MockOracle> = {};
    jsonAddressData?: unknown;

    // -------------------------------------------------------------------------
    // DEPLOYMENT
    // -------------------------------------------------------------------------

    async doDeploy(): Promise<void> {
        const deployed = await deployUSG(CONFIG.USER_COUNT, CONFIG.INITIAL_USG_SUPPLY);

        this.baseContext = deployed.baseContext;
        this.marketContext = deployed.marketContext;
        this.oracleContext = deployed.oracleContext;
        this.lpDeployContext = deployed.lpDeployContext;
        this.wStableContext = deployed.wStableContext;

        const markets = [
            ...Object.values(this.marketContext.convexFxnMarkets),
            ...Object.values(this.marketContext.convexCrvMarkets),
            ...Object.values(this.marketContext.pendlePTMarkets),
        ];

        this.marketAddresses = await Promise.all(markets.map((m) => m.getAddress()));
        this.userAddresses = await Promise.all(this.baseContext.users.map((u) => u.getAddress()));

        this.jsonAddressData = await createJSONAddress(deployed.baseContext, deployed.marketContext, deployed.oracleContext, deployed.lpDeployContext, deployed.wStableContext);
    }

    // -------------------------------------------------------------------------
    // MARKET INFO
    // -------------------------------------------------------------------------

    async getMarketInfo(marketAddress: string): Promise<MarketInfo> {
        if (this.marketInfoCache[marketAddress]) {
            return this.marketInfoCache[marketAddress];
        }

        const addresses = loadAddresses();
        const market = await ethers.getContractAt("MarketExternalActions", marketAddress);
        const collatTokenAddress = await market.collatToken();
        const collatToken = await ethers.getContractAt("IERC20Metadata", collatTokenAddress);
        const oracleAddress = await market.collatOracle();
        const oracle = await ethers.getContractAt("IPriceOracle", oracleAddress);

        const [collatDecimals, collateralPrice, maxLTV, liquidationThreshold, maxMarketDebt, minimumLoan] = await Promise.all([
            collatToken.decimals(),
            oracle.latestAnswer(true),
            market.maxLTV(),
            market.liquidationThreshold(),
            market.maxMarketDebt(),
            market.minimumLoan(),
        ]);

        const collatName = addresses?.markets?.find((m: {marketAddress: string}) => m.marketAddress.toLowerCase() === marketAddress.toLowerCase())?.collatName;

        const data: MarketInfo = {
            collatName,
            marketAddress,
            maxLTV,
            liquidationThreshold,
            collateralPrice,
            collatDecimals,
            maxMarketDebt,
            minimumLoan,
        };

        this.marketInfoCache[marketAddress] = data;
        return data;
    }

    // -------------------------------------------------------------------------
    // ORACLE MANIPULATION
    // -------------------------------------------------------------------------

    async setOracleToMock(marketAddress: string): Promise<void> {
        const market = await ethers.getContractAt("MarketExternalActions", marketAddress);
        const oracle = await ethers.getContractAt("IPriceOracle", await market.collatOracle());
        const lastPrice = await oracle.latestAnswer(true);

        const mockOracle = await ethers.deployContract("MockOracle");

        // Price drop creates liquidatable but not seizable positions
        // At 66% price with 62-65% LTV: health ratio ~0.94-0.99 < 1
        const targetPrice = (lastPrice * CONFIG.ORACLE_PRICE_DROP_PERCENT) / 100n;
        await mockOracle.setLastAnswer(targetPrice);
        await market.setCollatOracle(await mockOracle.getAddress());

        console.log(`setOracleToMock: ${marketAddress} → ${ethers.formatEther(targetPrice)} (${CONFIG.ORACLE_PRICE_DROP_PERCENT}% of ${ethers.formatEther(lastPrice)})`);

        this.mockOracles[marketAddress] = mockOracle;
    }

    async setOraclesToMock(): Promise<void> {
        if (!this.marketContext) return;

        const allMarkets = [
            ...Object.values(this.marketContext.convexCrvMarkets),
            ...Object.values(this.marketContext.convexFxnMarkets),
            ...Object.values(this.marketContext.pendlePTMarkets),
        ];

        for (const market of allMarkets) {
            await this.setOracleToMock(await market.getAddress());
        }
    }

    // -------------------------------------------------------------------------
    // POSITION GENERATION
    // -------------------------------------------------------------------------

    private async buildMarketLimits(marketAddresses: string[], excludedAddresses: string[]): Promise<Record<string, MarketLimits>> {
        const limits: Record<string, MarketLimits> = {};

        for (const marketAddress of marketAddresses) {
            if (excludedAddresses.includes(marketAddress)) continue;

            const info = await this.getMarketInfo(marketAddress);
            const market = await ethers.getContractAt("MarketExternalActions", marketAddress);
            const initialTotalDebt = await market.totalDebt();

            const safetyMargin = (info.maxMarketDebt * CONFIG.DEBT_SAFETY_MARGIN_PERCENT) / 100n;
            const effectiveMaxDebt = info.maxMarketDebt - safetyMargin;

            limits[marketAddress] = {
                maxMarketDebt: info.maxMarketDebt,
                minimumLoan: info.minimumLoan,
                initialTotalDebt,
                effectiveMaxDebt,
            };

            console.log(
                `📊 ${info.collatName}: maxDebt=${ethers.formatEther(info.maxMarketDebt)}, ` +
                    `minLoan=${ethers.formatEther(info.minimumLoan)}, initialDebt=${ethers.formatEther(initialTotalDebt)}`
            );
        }

        return limits;
    }

    private async generateUserPosition(
        marketAddress: string,
        currentTotalDebt: bigint,
        limits: MarketLimits
    ): Promise<{deposit: string; borrow: string; newTotalDebt: bigint; intent: PositionIntent} | null> {
        const {collateralPrice, collatDecimals} = await this.getMarketInfo(marketAddress);

        const usd = getRandomPositionSizeUSD();
        const positionValue = (usd * 10n ** collatDecimals * 10n ** 18n + collateralPrice - 1n) / collateralPrice;

        const {intent, borrowPercentage} = getRandomPositionType();
        const effectiveMinBorrow = limits.minimumLoan > CONFIG.MIN_BORROW_USG ? limits.minimumLoan : CONFIG.MIN_BORROW_USG;

        let borrowAmountWei = (usd * BigInt(Math.floor(borrowPercentage * 10000)) * 10n ** 18n) / 10000n;

        if (borrowAmountWei < effectiveMinBorrow) {
            borrowAmountWei = effectiveMinBorrow;
        }

        // Check capacity
        if (currentTotalDebt + borrowAmountWei > limits.effectiveMaxDebt) {
            const remaining = limits.effectiveMaxDebt - currentTotalDebt;
            if (remaining < effectiveMinBorrow) return null;
            borrowAmountWei = remaining;
        }

        return {
            deposit: formatEther(positionValue),
            borrow: formatEther(borrowAmountWei),
            newTotalDebt: currentTotalDebt + borrowAmountWei,
            intent,
        };
    }

    async getBorrowAndDepositParams(): Promise<{depositParams: UserMarketParams; borrowParams: UserMarketParams}> {
        const excludedAddresses = getExcludedAddresses();
        const marketLimits = await this.buildMarketLimits(this.marketAddresses, excludedAddresses);

        const depositParams: UserMarketParams = {};
        const borrowParams: UserMarketParams = {};
        const intentCount: Record<PositionIntent, number> = {safe: 0, liquidatable: 0, seizable: 0};
        let positionCount = 0;

        for (const marketAddress of this.marketAddresses) {
            if (excludedAddresses.includes(marketAddress)) continue;
            if (positionCount >= CONFIG.MAX_POSITION_COUNT) break;

            const limits = marketLimits[marketAddress];
            if (!limits) continue;

            const availableDebt = limits.effectiveMaxDebt - limits.initialTotalDebt;
            if (availableDebt < limits.minimumLoan) {
                const info = await this.getMarketInfo(marketAddress);
                console.log(`⚠️  ${info.collatName}: insufficient capacity (${ethers.formatEther(availableDebt)} available)`);
                continue;
            }

            let currentTotalDebt = limits.initialTotalDebt;
            const marketDeposits: Record<string, string> = {};
            const marketBorrows: Record<string, string> = {};

            for (const userAddress of this.userAddresses) {
                if (positionCount >= CONFIG.MAX_POSITION_COUNT) break;
                if (Math.random() < CONFIG.SKIP_USER_PROBABILITY) continue;

                const position = await this.generateUserPosition(marketAddress, currentTotalDebt, limits);
                if (!position) continue;

                marketDeposits[userAddress] = position.deposit;
                marketBorrows[userAddress] = position.borrow;
                currentTotalDebt = position.newTotalDebt;
                intentCount[position.intent]++;
                positionCount++;
            }

            depositParams[marketAddress] = marketDeposits;
            borrowParams[marketAddress] = marketBorrows;
        }

        console.log("Position distribution:", intentCount);
        return {depositParams, borrowParams};
    }

    // -------------------------------------------------------------------------
    // EXECUTION
    // -------------------------------------------------------------------------

    async doDepositAndBorrow(): Promise<void> {
        if (!this.marketAddresses.length || !this.userAddresses.length || !this.baseContext) {
            throw new Error("Contracts not deployed");
        }

        const {depositParams, borrowParams} = await this.getBorrowAndDepositParams();

        // Debug output
        const outputPath = path.join(process.cwd(), "borrowParams.json");
        fs.writeFileSync(outputPath, JSON.stringify(borrowParams, null, 2));

        await deposit(this.baseContext.users as HardhatEthersSigner[], depositParams);
        await borrow(this.baseContext.users as HardhatEthersSigner[], borrowParams);
    }
}
