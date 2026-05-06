import {ethers} from "hardhat";
import {formatEther, formatUnits, MaxUint256, parseUnits} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import * as fs from "fs";
import * as path from "path";

import {BaseContext, createJSONAddress} from "./BaseContext";
import {MarketContext} from "./MarketContext";
import {OracleContext} from "./OracleContext";
import {LpDeployContext} from "./LPDeployContext";
import {WStablesContext} from "./WStableContext";

import {deployUSG} from "../actions/deployUSG";
import {loadAddresses, UserMarketParams, AddressMarketEntry} from "../actions/common";
import {deposit} from "../actions/deposit";
import {borrow} from "../actions/borrow";

import {MockOracle} from "../../../../typechain-types";
import { deployMainnetAddresses } from "../actions/deployMainnetAddresses";
import { impersonateAccount, setBalance, stopImpersonatingAccount } from "@nomicfoundation/hardhat-toolbox/network-helpers";

const DEFAULT_ENSO_ROUTER = "0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf";
const DEFAULT_LIQUIDATION_USDC_PER_WALLET = "2000";

// ============================================================================
// CONFIGURATION TYPES
// ============================================================================

export type LiquidationConfig = {
    USER_COUNT: number;
    MAX_POSITION_COUNT?: number;
    MIN_BORROW_USG?: bigint;
    ORACLE_PRICE_DROP_PERCENT: bigint;
    DEBT_SAFETY_MARGIN_PERCENT?: bigint;
    SKIP_USER_PROBABILITY?: number;
    EXCLUDED_MARKETS?: readonly string[];
    INCLUDED_MARKETS?: readonly string[];
    // Simple mode specific
    SEED_USG_LP_AMOUNT?: number;
    USERS_TO_USE?: number; // Number of users to actually use (for simple mode)
    // Position size distribution (for chaos mode)
    POSITION_SIZE?: {
        SMALL: {value: bigint; probability: number};
        MEDIUM: {min: bigint; max: bigint; probability: number};
        LARGE: {min: bigint; max: bigint; probability: number};
    };
    // Position type distribution (for chaos mode)
    POSITION_TYPES?: {
        SAFE: {ltvRange: [number, number]; probability: number};
        LIQUIDATABLE: {ltvRange: [number, number]; probability: number};
        SEIZABLE: {ltvRange: [number, number]; probability: number};
    };
    // Mode: 'simple' uses fixed positions, 'chaos' uses random distribution
    MODE: "simple" | "chaos";
};

// ============================================================================
// TYPES
// ============================================================================

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
    maxMarketDebt?: bigint;
    minimumLoan?: bigint;
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

function getRandomPositionSizeUSD(config: LiquidationConfig): bigint {
    if (!config.POSITION_SIZE) {
        throw new Error("POSITION_SIZE not defined in config");
    }
    const rand = Math.random();
    const {SMALL, MEDIUM, LARGE} = config.POSITION_SIZE;

    if (rand < SMALL.probability) {
        return SMALL.value;
    }
    if (rand < SMALL.probability + MEDIUM.probability) {
        return randomBigIntBetween(MEDIUM.min, MEDIUM.max);
    }
    return randomBigIntBetween(LARGE.min, LARGE.max);
}

function getRandomPositionType(config: LiquidationConfig): {intent: PositionIntent; borrowPercentage: number} {
    if (!config.POSITION_TYPES) {
        throw new Error("POSITION_TYPES not defined in config");
    }
    const rand = Math.random();
    const {SAFE, LIQUIDATABLE, SEIZABLE} = config.POSITION_TYPES;

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

async function getFilteredMarkets(config: LiquidationConfig): Promise<string[]> {
    const addresses = await loadAddresses();
    const markets = (addresses.markets || []) as AddressMarketEntry[];
    const resolveMarketAddress = (name: string): string | undefined =>
        markets.find((m) => m.collatName === name || m.marketName === name)?.marketAddress;

    // If INCLUDED_MARKETS is specified, only include those markets
    if (config.INCLUDED_MARKETS && config.INCLUDED_MARKETS.length > 0) {
        return config.INCLUDED_MARKETS.map((name) => resolveMarketAddress(name)).filter(Boolean) as string[];
    }

    // Otherwise, exclude markets from EXCLUDED_MARKETS
    if (!config.EXCLUDED_MARKETS || config.EXCLUDED_MARKETS.length === 0) {
        return markets.map((m) => m.marketAddress);
    }

    const excludedAddresses = config.EXCLUDED_MARKETS.map((name) => resolveMarketAddress(name)).filter(Boolean);
    return markets.map((m) => m.marketAddress).filter((addr: string)  => !excludedAddresses.includes(addr));
}

// ============================================================================
// MAIN CLASS
// ============================================================================

export class LiquidationContext {
    // Configuration
    private config: LiquidationConfig;

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

    constructor(config: LiquidationConfig) {
        this.config = config;
    }

    // -------------------------------------------------------------------------
    // DEPLOYMENT
    // -------------------------------------------------------------------------

    async doDeploy(): Promise<void> {
        const deployed = await deployMainnetAddresses(this.config.USER_COUNT, this.config.SEED_USG_LP_AMOUNT);

        this.baseContext = deployed.baseContext;
        this.marketContext = deployed.marketContext;
        this.oracleContext = deployed.oracleContext;
        this.lpDeployContext = deployed.lpDeployContext;
        this.wStableContext = deployed.wStableContext;

        const markets = [
            ...Object.values(this.marketContext.convexFxnMarkets),
            ...Object.values(this.marketContext.convexCrvMarkets),
            ...Object.values(this.marketContext.basicERC20Markets),
            ...Object.values(this.marketContext.curveGaugeMarkets),
            ...Object.values(this.marketContext.stakeDaoVaultMarkets),
        ];

        this.marketAddresses = await Promise.all(markets.map((m) => m.getAddress()));

        // For simple mode, only use a subset of users
        const usersToUse = this.config.MODE === "simple" && this.config.USERS_TO_USE ? this.baseContext.users.slice(0, this.config.USERS_TO_USE) : this.baseContext.users;
        this.userAddresses = await Promise.all(usersToUse.map((u) => u.getAddress()));

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

        const baseFields = await Promise.all([collatToken.decimals(), oracle.latestAnswer(true), market.maxLTV(), market.liquidationThreshold()]);

        const collatDecimals = baseFields[0];
        const collateralPrice = baseFields[1];
        const maxLTV = baseFields[2];
        const liquidationThreshold = baseFields[3];

        // For chaos mode, also get maxMarketDebt and minimumLoan
        let maxMarketDebt: bigint | undefined;
        let minimumLoan: bigint | undefined;
        if (this.config.MODE === "chaos") {
            [maxMarketDebt, minimumLoan] = await Promise.all([market.maxMarketDebt(), market.minimumLoan()]);
        }

        const matchingMarket = addresses?.markets?.find((m: AddressMarketEntry) => m.marketAddress.toLowerCase() === marketAddress.toLowerCase());
        const collatName = matchingMarket?.collatName || matchingMarket?.marketName;

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
        if (!this.baseContext) {
            throw new Error("BaseContext not initialized");
        }

        const market = await ethers.getContractAt("MarketExternalActions", marketAddress);
        const oracle = await ethers.getContractAt("IPriceOracle", await market.collatOracle());
        const lastPrice = await oracle.latestAnswer(true);

        const mockOracle = await ethers.deployContract("MockOracle");

        // Price drop creates liquidatable but not seizable positions
        // At 66% price with 62-65% LTV: health ratio ~0.94-0.99 < 1
        const targetPrice = (lastPrice * this.config.ORACLE_PRICE_DROP_PERCENT) / 100n;
        await mockOracle.setLastAnswer(targetPrice);
        const ownerAddress = await this.baseContext.owner.getAddress();
        await impersonateAccount(ownerAddress);
        try {
            await market.connect(this.baseContext.owner).setCollatOracle(await mockOracle.getAddress());
        } finally {
            await stopImpersonatingAccount(ownerAddress);
        }

        console.log(`setOracleToMock: ${marketAddress} → ${ethers.formatEther(targetPrice)} (${this.config.ORACLE_PRICE_DROP_PERCENT}% of ${ethers.formatEther(lastPrice)})`);

        this.mockOracles[marketAddress] = mockOracle;
    }

    async setOraclesToMock(): Promise<void> {
        if (!this.marketContext) return;

        const allMarkets = [
            ...Object.values(this.marketContext.convexCrvMarkets),
            ...Object.values(this.marketContext.convexFxnMarkets),
            ...Object.values(this.marketContext.basicERC20Markets),
            ...(this.config.MODE === "simple" ? [...Object.values(this.marketContext.curveGaugeMarkets), ...Object.values(this.marketContext.stakeDaoVaultMarkets)] : []),
        ];

        for (const market of allMarkets) {
            await this.setOracleToMock(await market.getAddress());
        }
    }

    // -------------------------------------------------------------------------
    // POSITION GENERATION - SIMPLE MODE
    // -------------------------------------------------------------------------

    private async getBorrowAndDepositParamsSimple(marketAddresses: string[], userAddresses: string[]): Promise<{depositParams: UserMarketParams; borrowParams: UserMarketParams}> {
        const depositParams: UserMarketParams = {};
        const borrowParams: UserMarketParams = {};

        for (const marketaddress of marketAddresses) {
            const currentMarketDeposit: Record<string, string> = {};
            const currentMarketBorrow: Record<string, string> = {};
            let hasEnoughTokens = false;

            const market = await ethers.getContractAt("MarketExternalActions", marketaddress);
            const collatTokenAddress = await market.collatToken();
            const collatToken = await ethers.getContractAt("IERC20", collatTokenAddress);
            const marketInfo = await this.getMarketInfo(marketaddress);

            const USD = 10_000n;
            const PRICE = marketInfo.collateralPrice;
            const DECIMALS = marketInfo.collatDecimals;
            // we deposit the equivalent of 10_000 USD in collateral
            const position10000Value = (USD * 10n ** DECIMALS * 10n ** 18n) / PRICE;
            const depositAmount = position10000Value;

            // Check if users have enough tokens before creating positions
            for (let userIndex = 0; userIndex < userAddresses.length; userIndex++) {
                const userAddress = userAddresses[userIndex];

                const balance = await collatToken.balanceOf(userAddress);
                console.log("balance", marketInfo.collatName, balance);

                if (balance >= depositAmount) {
                    hasEnoughTokens = true;
                    currentMarketDeposit[userAddress] = formatEther(depositAmount);

                    // Simple mode alternates deterministic position types:
                    // user 0: liquidatable at 64% LTV, user 1: seizable at 80% LTV.
                    const isSeizableUser = userIndex % 2 === 1;
                    if (isSeizableUser) {
                        // SEIZABLE: 80% LTV = 8000 USD (or maxLTV if it's lower than 80%)
                        // maxLTV is in basis points (100_000 = 100%)
                        const DENOMINATOR = 100_000n;
                        const maxBorrowUSD = (USD * marketInfo.maxLTV) / DENOMINATOR;
                        // Target 80% LTV for seizable, but use maxLTV if it's lower
                        const targetSeizableBorrowUSD = 8000n; // 80% of 10k
                        const seizableBorrowUSD = maxBorrowUSD < targetSeizableBorrowUSD ? maxBorrowUSD : targetSeizableBorrowUSD;
                        // Borrow is in USD (not wei), so convert to string directly
                        currentMarketBorrow[userAddress] = seizableBorrowUSD.toString();
                    } else {
                        // LIQUIDATABLE: 64% LTV = 6400 USD
                        // This ensures healthRatio < 1 after 66% price drop even with 94% liquidation threshold
                        // healthRatio = (6600 * 0.94) / 6400 = 0.97 < 1 ✓
                        currentMarketBorrow[userAddress] = "6400";
                    }
                }
            }

            // Only add market if at least one user has enough tokens
            if (hasEnoughTokens && Object.keys(currentMarketDeposit).length > 0) {
                depositParams[marketaddress] = currentMarketDeposit;
                borrowParams[marketaddress] = currentMarketBorrow;
            }
        }

        return {depositParams, borrowParams};
    }

    // -------------------------------------------------------------------------
    // POSITION GENERATION - CHAOS MODE
    // -------------------------------------------------------------------------

    private async buildMarketLimits(marketAddresses: string[], excludedAddresses: string[]): Promise<Record<string, MarketLimits>> {
        const limits: Record<string, MarketLimits> = {};

        // Get MarketViewer address from addresses.json
        const addresses = await loadAddresses();
        const marketViewerAddress = addresses.utilities?.marketViewer;
        if (!marketViewerAddress) {
            throw new Error("MarketViewer address not found in addresses.json");
        }
        const marketViewer = await ethers.getContractAt("MarketViewer", marketViewerAddress);

        for (const marketAddress of marketAddresses) {
            if (excludedAddresses.includes(marketAddress)) continue;

            const info = await this.getMarketInfo(marketAddress);
            if (!info.maxMarketDebt || !info.minimumLoan) {
                throw new Error(`Market ${marketAddress} missing maxMarketDebt or minimumLoan`);
            }

            const market = await ethers.getContractAt("MarketExternalActions", marketAddress);
            // Use MarketViewer.totalDebt() instead of market.totalDebt()
            const initialTotalDebt = await marketViewer.totalDebt(market);


            limits[marketAddress] = {
                maxMarketDebt: info.maxMarketDebt,
                minimumLoan: info.minimumLoan,
                initialTotalDebt,
                effectiveMaxDebt:info.maxMarketDebt,
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

        const usd = getRandomPositionSizeUSD(this.config);
        const positionValue = (usd * 10n ** collatDecimals * 10n ** 18n) / collateralPrice;

        const {intent, borrowPercentage} = getRandomPositionType(this.config);
        const effectiveMinBorrow = limits.minimumLoan > (this.config.MIN_BORROW_USG || 0n) ? limits.minimumLoan : this.config.MIN_BORROW_USG || 0n;

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

    private async getBorrowAndDepositParamsChaos(): Promise<{depositParams: UserMarketParams; borrowParams: UserMarketParams}> {
        const filteredMarketAddresses = await getFilteredMarkets(this.config);

        const marketLimits = await this.buildMarketLimits(filteredMarketAddresses, []);

        const depositParams: UserMarketParams = {};
        const borrowParams: UserMarketParams = {};
        const intentCount: Record<PositionIntent, number> = {safe: 0, liquidatable: 0, seizable: 0};
        let positionCount = 0;
        const maxPositionCount = this.config.MAX_POSITION_COUNT || Infinity;

        // Track current total debt per market
        const marketCurrentDebt: Record<string, bigint> = {};
        for (const marketAddress of filteredMarketAddresses) {
            const limits = marketLimits[marketAddress];
            if (limits) {
                marketCurrentDebt[marketAddress] = limits.initialTotalDebt;
            }
        }

        for (const userAddress of this.userAddresses) {
            if (positionCount >= maxPositionCount) break;
          

            for (const marketAddress of filteredMarketAddresses) {
                if (positionCount >= maxPositionCount) break;

                if (this.config.SKIP_USER_PROBABILITY && Math.random() < this.config.SKIP_USER_PROBABILITY) continue;

                const limits = marketLimits[marketAddress];
                if (!limits) continue;

                const availableDebt = limits.effectiveMaxDebt - marketCurrentDebt[marketAddress];
                if (availableDebt < limits.minimumLoan) {
                    continue;
                }

                const position = await this.generateUserPosition(marketAddress, marketCurrentDebt[marketAddress], limits);
                if (!position) continue;

                if (!depositParams[marketAddress]) {
                    depositParams[marketAddress] = {};
                    borrowParams[marketAddress] = {};
                }

                depositParams[marketAddress][userAddress] = position.deposit;
                borrowParams[marketAddress][userAddress] = position.borrow;
                marketCurrentDebt[marketAddress] = position.newTotalDebt;
                intentCount[position.intent]++;
                positionCount++;
            }
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

        // Apply market filtering based on INCLUDED_MARKETS or EXCLUDED_MARKETS
        const filteredMarketAddresses = await getFilteredMarkets(this.config);

        let depositParams: UserMarketParams;
        let borrowParams: UserMarketParams;

        if (this.config.MODE === "simple") {
            const result = await this.getBorrowAndDepositParamsSimple(filteredMarketAddresses, this.userAddresses);
            depositParams = result.depositParams;
            borrowParams = result.borrowParams;
        } else {
            const result = await this.getBorrowAndDepositParamsChaos();
            depositParams = result.depositParams;
            borrowParams = result.borrowParams;

            // Debug output for chaos mode
            const outputPath = path.join(process.cwd(), "borrowParams.json");
            fs.writeFileSync(outputPath, JSON.stringify(borrowParams, null, 2));
        }

        await deposit(this.baseContext.users as HardhatEthersSigner[], depositParams);
        await borrow(this.baseContext.users as HardhatEthersSigner[], borrowParams);
        await this.prepareLiquidationWallets();
    }

    async prepareLiquidationWallets(): Promise<void> {
        if (!this.baseContext) {
            throw new Error("BaseContext not initialized");
        }

        const walletPks = (process.env.WALLET_PKS || "")
            .split(",")
            .map((pk) => pk.trim())
            .filter(Boolean);

        if (!walletPks.length) {
            console.log("No WALLET_PKS configured, skipping liquidation wallet USDC funding and Enso approval");
            return;
        }

        const ensoRouter = process.env.ENSO_ROUTER || DEFAULT_ENSO_ROUTER;
        const usdc = this.baseContext.coins["USDC"];
        const usdcPerWallet = parseUnits(process.env.LIQUIDATION_USDC_PER_WALLET || DEFAULT_LIQUIDATION_USDC_PER_WALLET, 6);
        const ownerAddress = await this.baseContext.owner.getAddress();
        const ownerBalance = await usdc.balanceOf(ownerAddress);
        const totalRequired = usdcPerWallet * BigInt(walletPks.length);

        if (ownerBalance < totalRequired) {
            throw new Error(
                `Not enough USDC on setup owner to fund liquidation wallets: required=${formatUnits(totalRequired, 6)}, balance=${formatUnits(ownerBalance, 6)}`
            );
        }

        await impersonateAccount(ownerAddress);
        try {
            for (const pk of walletPks) {
                const wallet = new ethers.Wallet(pk, ethers.provider);
                await setBalance(wallet.address, ethers.parseEther("1000"));
                await usdc.connect(this.baseContext.owner).transfer(wallet.address, usdcPerWallet);
                await usdc.connect(wallet).approve(ensoRouter, MaxUint256);
                console.log(`Prepared liquidation wallet ${wallet.address}: funded ${formatUnits(usdcPerWallet, 6)} USDC and approved Enso router ${ensoRouter}`);
            }
        } finally {
            await stopImpersonatingAccount(ownerAddress);
        }
    }
}
