import {ethers} from "hardhat";
import {formatEther, parseEther} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";

import {deposit} from "../actions/deposit";
import {borrow} from "../actions/borrow";
import {loadAddresses} from "../actions/common";

import {BaseContext} from "./BaseContext";
import {MockOracle} from "../../../../typechain-types";

export type LiquidationTestPosition = {
    id: number;
    market: string; // collatName as in addresses.json
    lpDeposited: string;
    debt: string;
};

export type LiquidationTestData = {
    positions: LiquidationTestPosition[];
    prices: Record<string, Record<string, string>>;
};

export class LiquidationTestContext {
    readonly data: LiquidationTestData;
    readonly maxUser: number;

    private baseContext?: BaseContext;
    private mockOraclesByCollatName: Record<string, MockOracle> = {};

    constructor(data: LiquidationTestData) {
        this.data = data;

        // Keep a minimum to avoid accidental under-provisioning
        this.maxUser = this.getMaxUser(data);
    }

    getMaxUser = (data: LiquidationTestData) => {
        // find the max user per markets
        const maxUserPerMarket = new Map<string, number>();
        for (const testCase of data.positions) {
            const market = testCase.market;
            const userCount = maxUserPerMarket.get(market) || 0;
            maxUserPerMarket.set(market, userCount + 1);
        }
        return Math.max(...maxUserPerMarket.values());
    };

    async init(deployed: {baseContext: BaseContext}): Promise<void> {
        this.baseContext = deployed.baseContext;

        // 1) Apply initial prices (state_0)
        await this.applyPricesForState("state_0");

        // 2) Deploy all positions (deposit + borrow)
        await this.deployAllPositions();
    }

    async runState_1(): Promise<void> {
        await this.applyPricesForState("state_1");
    }

    async runState_2(): Promise<void> {
        await this.applyPricesForState("state_2");
    }

    async runState_3(): Promise<void> {
        await this.applyPricesForState("state_3");
    }

    private requireBaseContext(): BaseContext {
        if (!this.baseContext) {
            throw new Error("LiquidationTestContext not initialized (missing baseContext). Call init() first.");
        }
        return this.baseContext;
    }

    private getMarketAddressByCollatName(collatName: string): string {
        const addresses = loadAddresses();
        const market = addresses?.markets?.find((m: any) => m.collatName === collatName);
        if (!market?.marketAddress) {
            throw new Error(`Unknown collatName '${collatName}' (not found in addresses.json markets[])`);
        }
        return market.marketAddress as string;
    }

    private async setOraclePrice(collatName: string, price: string): Promise<void> {
        const baseContext = this.requireBaseContext();
        const marketAddress = this.getMarketAddressByCollatName(collatName);
        const market = await ethers.getContractAt("MarketExternalActions", marketAddress);

        // Ensure we have a mock oracle installed for this market
        if (!this.mockOraclesByCollatName[collatName]) {
            const mockOracle = await ethers.deployContract("MockOracle");
            await market.connect(baseContext.owner).setCollatOracle(await mockOracle.getAddress());
            this.mockOraclesByCollatName[collatName] = mockOracle as unknown as MockOracle;
        }

        const mockOracle = this.mockOraclesByCollatName[collatName];
        await mockOracle.connect(baseContext.owner).setLastAnswer(parseEther(price));
    }

    private async applyPricesForState(stateKey: string): Promise<void> {
        const statePrices = this.data.prices?.[stateKey];
        if (!statePrices) return;

        for (const [collatName, price] of Object.entries(statePrices)) {
            await this.setOraclePrice(collatName, price);
        }
    }

    private async deployAllPositions(): Promise<void> {
        const baseContext = this.requireBaseContext();
        const users = baseContext.users as unknown as HardhatEthersSigner[];

        // userAmountByMarket[marketAddress][userAddress] = amount (string in 18 decimals)
        const depositParams: Record<string, Record<string, string>> = {};
        const borrowParams: Record<string, Record<string, string>> = {};

        let userIndex = 0;
        let currentMarket: string | null = null;

        for (let i = 0; i < this.data.positions.length; i++) {
            const pos = this.data.positions[i];
            const marketAddress = this.getMarketAddressByCollatName(pos.market);

            // Reset user index when market changes
            if (currentMarket !== marketAddress) {
                currentMarket = marketAddress;
                userIndex = 0;
            } else {
                userIndex++;
            }
            const user = users[userIndex];
            if (!user) {
                throw new Error(`Not enough users for market ${pos.market}: position id=${pos.id} requires userIndex=${userIndex}`);
            }
            depositParams[marketAddress] ||= {};
            borrowParams[marketAddress] ||= {};

            // If multiple entries target same (market,user), sum them.
            depositParams[marketAddress][user.address] = pos.lpDeposited;
            borrowParams[marketAddress][user.address] = pos.debt;
        }

        await deposit(users, depositParams);
        await borrow(users, borrowParams);
    }
}
