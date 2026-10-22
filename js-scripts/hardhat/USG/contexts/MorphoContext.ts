import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {time} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import {ContractTransactionResponse, MaxUint256, formatEther, parseEther} from "ethers";
import {ethers} from "hardhat";
import {giveTokenToAddress, giveTokenToAddresss} from "../../thief/thief";
import {IERC20, IMorpho, MockMorphoOracle} from "../../../../typechain-types";
import hardhatConfig from "../../../../hardhat.config";

export const MORPHO_BLUE = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb";
export const EXPECTED_MARKET_ID = "0x2a2f62fe3d123077da35f281fbe69ebc296759b34873d627cf44c94f05fecf7e";
export const MORPHO_MARKET_CREATION_BLOCK_MAINNET = 25286961;

export interface MorphoMarketParams {
    loanToken: string;
    collateralToken: string;
    oracle: string;
    irm: string;
    lltv: bigint;
}

// Mainnet sUSG/frxUSD market params (market created at block 25286961, after our fork block,
// hence the createMarket replay below — the id is a deterministic hash of these params).
export const PROD_MARKET_PARAMS: MorphoMarketParams = {
    loanToken: "0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29", // frxUSD
    collateralToken: "0xF17D6f98A5C6EAA99d149079984119e0A4EF6900", // sUSG
    oracle: "0x983C54E46F6fe7793fA4fD01B72fC3c065AE1b11",
    irm: "0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC", // AdaptiveCurveIRM
    lltv: 860000000000000000n, // 86%
};

// The `morpho` section of the generated addresses.json (consumed by tangent-indexer).
// Locally createMarket lands a few blocks after the fork base, so the fork base block is the
// safe scan-start; in the prod addresses.json (Tangent-labs/public-files) creationBlock must
// be MORPHO_MARKET_CREATION_BLOCK_MAINNET instead.
const LOCAL_FORK_BLOCK = (hardhatConfig.networks?.localhost as {forking?: {blockNumber?: number}})?.forking?.blockNumber ?? 25277148;
export const MORPHO_ADDRESSES_JSON = {
    singleton: MORPHO_BLUE.toLowerCase(),
    markets: {
        "sUSG-frxUSD": {
            id: EXPECTED_MARKET_ID,
            collateralToken: PROD_MARKET_PARAMS.collateralToken.toLowerCase(),
            loanToken: PROD_MARKET_PARAMS.loanToken.toLowerCase(),
            creationBlock: LOCAL_FORK_BLOCK,
        },
    },
};

const ORACLE_PRICE_SCALE = 10n ** 36n;
// sUSG is not in THIEF_TOKEN_CONFIG: Yearn V3 vault (Vyper), balance_of mapping at slot 18
// (found by storage probing on the fork)
const SUSG_BALANCE_SLOT = 18;

export interface MorphoStep {
    scenario: string;
    action: string;
    caller: string;
    block: number;
    tx: string;
    events: {name: string; args: Record<string, string>}[];
}

export class MorphoContext {
    morpho!: IMorpho;
    sUSG!: IERC20;
    frxUSD!: IERC20;
    marketParams: MorphoMarketParams = {...PROD_MARKET_PARAMS};
    marketId: string = EXPECTED_MARKET_ID;
    oracleMode: "real" | "mock" = "real";
    mockOracle?: MockMorphoOracle;

    accounts: Record<string, HardhatEthersSigner> = {};
    steps: MorphoStep[] = [];

    async setup() {
        const signers = await ethers.getSigners();
        this.accounts = {
            ops: signers[0],
            loanSupplier: signers[1],
            userA: signers[2], // simple supply / partial withdraw / full exit
            userB: signers[3], // caller supplying on behalf of userC
            userC: signers[4], // beneficiary of userB's supply
            userD: signers[5], // looped/leveraged position
            userE: signers[6], // liquidated borrower
            userF: signers[7], // bad debt borrower
            liquidator: signers[8],
            utilizationFiller: signers[9], // pushes utilization up so interest accrual is fast (real-oracle mode)
        };
        this.morpho = await ethers.getContractAt("IMorpho", MORPHO_BLUE);
        this.sUSG = await ethers.getContractAt("IERC20", this.marketParams.collateralToken);
        this.frxUSD = await ethers.getContractAt("IERC20", this.marketParams.loanToken);
    }

    computeMarketId(params: MorphoMarketParams): string {
        return ethers.keccak256(
            ethers.AbiCoder.defaultAbiCoder().encode(
                ["address", "address", "address", "address", "uint256"],
                [params.loanToken, params.collateralToken, params.oracle, params.irm, params.lltv]
            )
        );
    }

    label(address: string): string {
        for (const [name, signer] of Object.entries(this.accounts)) {
            if (signer.address.toLowerCase() === address.toLowerCase()) return name;
        }
        return address;
    }

    // ---------------------------------------------------------------- market

    async oraclePrice(): Promise<bigint> {
        const oracle = await ethers.getContractAt("IMorphoOracle", this.marketParams.oracle);
        try {
            return await oracle.price();
        } catch (e) {
            throw new Error(`oracle.price() reverted (${this.oracleMode} mode). Restart the node and rerun with MORPHO_MOCK_ORACLE=1. ${e}`);
        }
    }

    // --------------------------------------------------------------- funding

    // Note: the thief utilities SET the balance (storage write), they do not add to it
    async fundCollateral(user: HardhatEthersSigner, amount: bigint) {
        await giveTokenToAddresss(user, this.marketParams.collateralToken, amount, SUSG_BALANCE_SLOT, true);
        await (await this.sUSG.connect(user).approve(MORPHO_BLUE, MaxUint256)).wait();
    }

    async fundLoanToken(user: HardhatEthersSigner, amount: bigint) {
        await giveTokenToAddress(user, "frxUSD", amount);
        await (await this.frxUSD.connect(user).approve(MORPHO_BLUE, MaxUint256)).wait();
    }

    // ------------------------------------------------------------- scenarios

    async seedLoanLiquidity(amount: bigint = parseEther("200000")) {
        const lp = this.accounts.loanSupplier;
        await this.fundLoanToken(lp, amount);
        const tx = await this.morpho.connect(lp).supply(this.marketParams, amount, 0n, lp.address, "0x");
        await this.record("seed-liquidity", `supply ${formatEther(amount)} frxUSD`, lp.address, tx);
    }

    // supplyCollateral / partial withdrawCollateral / full exit
    async scenarioSimple() {
        const user = this.accounts.userA;
        await this.fundCollateral(user, parseEther("10000"));
        const morpho = this.morpho.connect(user);

        let tx = await morpho.supplyCollateral(this.marketParams, parseEther("10000"), user.address, "0x");
        await this.record("simple", "supplyCollateral 10000 sUSG", user.address, tx);

        tx = await morpho.withdrawCollateral(this.marketParams, parseEther("4000"), user.address, user.address);
        await this.record("simple", "withdrawCollateral 4000 sUSG (partial)", user.address, tx);

        tx = await morpho.withdrawCollateral(this.marketParams, parseEther("6000"), user.address, user.address);
        await this.record("simple", "withdrawCollateral 6000 sUSG (full exit)", user.address, tx);
    }

    // caller != onBehalf: the indexer must credit userC, not userB
    async scenarioOnBehalf() {
        const caller = this.accounts.userB;
        const beneficiary = this.accounts.userC;
        await this.fundCollateral(caller, parseEther("5000"));

        let tx = await this.morpho.connect(caller).supplyCollateral(this.marketParams, parseEther("5000"), beneficiary.address, "0x");
        await this.record("on-behalf", "userB supplyCollateral 5000 sUSG onBehalf of userC", caller.address, tx);

        tx = await this.morpho.connect(beneficiary).withdrawCollateral(this.marketParams, parseEther("1000"), beneficiary.address, beneficiary.address);
        await this.record("on-behalf", "userC withdrawCollateral 1000 sUSG", beneficiary.address, tx);
    }

    // supply -> borrow frxUSD -> "swap" to sUSG (simulated via deal) -> re-supply, twice
    async scenarioLoop(iterations: number = 2) {
        const user = this.accounts.userD;
        const price = await this.oraclePrice();
        let supplyAmount = parseEther("10000");
        await this.fundCollateral(user, supplyAmount);
        const morpho = this.morpho.connect(user);

        for (let i = 0; i < iterations; i++) {
            let tx = await morpho.supplyCollateral(this.marketParams, supplyAmount, user.address, "0x");
            await this.record("loop", `loop ${i + 1}: supplyCollateral ${formatEther(supplyAmount)} sUSG`, user.address, tx);

            // borrow 60% of the freshly supplied collateral's value (total LTV stays well under the 86% lltv)
            const borrowAmount = (((supplyAmount * price) / ORACLE_PRICE_SCALE) * 60n) / 100n;
            tx = await morpho.borrow(this.marketParams, borrowAmount, 0n, user.address, user.address);
            await this.record("loop", `loop ${i + 1}: borrow ${formatEther(borrowAmount)} frxUSD`, user.address, tx);

            supplyAmount = (borrowAmount * ORACLE_PRICE_SCALE) / price;
            await this.fundCollateral(user, supplyAmount); // simulated frxUSD -> sUSG swap
        }
        const tx = await morpho.supplyCollateral(this.marketParams, supplyAmount, user.address, "0x");
        await this.record("loop", `loop end: supplyCollateral ${formatEther(supplyAmount)} sUSG`, user.address, tx);
    }

    // ----------------------------------------------------------- liquidation

    private async borrowAssetsOf(user: string): Promise<bigint> {
        const [market, position] = await Promise.all([this.morpho.market(this.marketId), this.morpho.position(this.marketId, user)]);
        if (position.borrowShares === 0n) return 0n;
        return (position.borrowShares * market.totalBorrowAssets + market.totalBorrowShares - 1n) / market.totalBorrowShares;
    }

    async openMaxBorrowPosition(user: HardhatEthersSigner, collateralAmount: bigint, scenario: string) {
        await this.fundCollateral(user, collateralAmount);
        const morpho = this.morpho.connect(user);
        let tx = await morpho.supplyCollateral(this.marketParams, collateralAmount, user.address, "0x");
        await this.record(scenario, `supplyCollateral ${formatEther(collateralAmount)} sUSG`, user.address, tx);

        const price = await this.oraclePrice();
        // 99.8% of max borrow: healthy at open, underwater after the first interest accrual / price drop
        const borrowAmount = (((((collateralAmount * price) / ORACLE_PRICE_SCALE) * this.marketParams.lltv) / parseEther("1")) * 998n) / 1000n;
        tx = await morpho.borrow(this.marketParams, borrowAmount, 0n, user.address, user.address);
        await this.record(scenario, `borrow ${formatEther(borrowAmount)} frxUSD (99.8% of max)`, user.address, tx);
    }

    // Real-oracle mode only: high utilization makes AdaptiveCurveIRM ramp rates up,
    // so evm_increaseTime jumps push max-borrowed positions underwater quickly.
    async pushUtilization(targetPercent: bigint = 99n) {
        if (this.oracleMode === "mock") return;
        const filler = this.accounts.utilizationFiller;
        const market = await this.morpho.market(this.marketId);
        const targetBorrow = (market.totalSupplyAssets * targetPercent) / 100n;
        if (market.totalBorrowAssets >= targetBorrow) return;
        const extraBorrow = targetBorrow - market.totalBorrowAssets;
        const price = await this.oraclePrice();
        const collateralNeeded = (((((extraBorrow * ORACLE_PRICE_SCALE) / price) * parseEther("1")) / this.marketParams.lltv) * 105n) / 100n;

        await this.fundCollateral(filler, collateralNeeded);
        const morpho = this.morpho.connect(filler);
        let tx = await morpho.supplyCollateral(this.marketParams, collateralNeeded, filler.address, "0x");
        await this.record("utilization-filler", `supplyCollateral ${formatEther(collateralNeeded)} sUSG`, filler.address, tx);
        tx = await morpho.borrow(this.marketParams, extraBorrow, 0n, filler.address, filler.address);
        await this.record("utilization-filler", `borrow ${formatEther(extraBorrow)} frxUSD (utilization -> ${targetPercent}%)`, filler.address, tx);
    }

    // Pushes the market until tryLiquidate() stops reverting: mock mode drops the oracle
    // price 4% per step, real mode jumps time so interest accrues.
    async makeLiquidatable(borrower: HardhatEthersSigner, tryLiquidate: () => Promise<boolean>, jumpSeconds: number, maxIterations: number, label: string) {
        for (let i = 0; i < maxIterations; i++) {
            if (await tryLiquidate()) {
                console.log(`${label}: liquidatable after ${i} step(s)`);
                return;
            }
            if (this.oracleMode === "mock") {
                const newPrice = ((await this.oraclePrice()) * 96n) / 100n;
                await (await this.mockOracle!.setPrice(newPrice)).wait();
                console.log(`${label}: mock oracle price -> ${formatEther(newPrice / 10n ** 18n)} frxUSD/sUSG`);
            } else {
                await time.increase(jumpSeconds);
                await (await this.morpho.accrueInterest(this.marketParams)).wait();
                console.log(`${label}: +${jumpSeconds / 86400} days, debt now ${formatEther(await this.borrowAssetsOf(borrower.address))} frxUSD`);
            }
        }
        throw new Error(`${label}: position still not liquidatable after ${maxIterations} steps`);
    }

    // partial liquidation -> Liquidate event with seizedAssets, no bad debt
    async scenarioLiquidation() {
        const borrower = this.accounts.userE;
        const liquidator = this.accounts.liquidator;
        const morpho = this.morpho.connect(liquidator);

        const tryLiquidate = async () => {
            const position = await this.morpho.position(this.marketId, borrower.address);
            try {
                await morpho.liquidate.staticCall(this.marketParams, borrower.address, 0n, position.borrowShares / 2n, "0x");
                return true;
            } catch {
                return false;
            }
        };
        await this.makeLiquidatable(borrower, tryLiquidate, 7 * 86400, 60, "liquidation");

        const position = await this.morpho.position(this.marketId, borrower.address);
        const tx = await morpho.liquidate(this.marketParams, borrower.address, 0n, position.borrowShares / 2n, "0x");
        await this.record("liquidation", "liquidate userE (repay half the borrow shares)", liquidator.address, tx);
    }

    // full collateral seizure with remaining debt -> Liquidate event with badDebtAssets > 0
    async scenarioBadDebt() {
        const borrower = this.accounts.userF;
        const liquidator = this.accounts.liquidator;
        const morpho = this.morpho.connect(liquidator);

        const tryLiquidate = async () => {
            const position = await this.morpho.position(this.marketId, borrower.address);
            try {
                await morpho.liquidate.staticCall(this.marketParams, borrower.address, position.collateral, 0n, "0x");
                return true;
            } catch {
                return false;
            }
        };
        await this.makeLiquidatable(borrower, tryLiquidate, 30 * 86400, 36, "bad-debt");

        const position = await this.morpho.position(this.marketId, borrower.address);
        const tx = await morpho.liquidate(this.marketParams, borrower.address, position.collateral, 0n, "0x");
        await this.record("bad-debt", "liquidate userF (seize full collateral, realize bad debt)", liquidator.address, tx);
    }

    async fundLiquidator(amount: bigint = parseEther("500000")) {
        await this.fundLoanToken(this.accounts.liquidator, amount);
    }

    // In mock mode, restore the original price after liquidations so the market is left in a sane state.
    async restoreMockPrice(price: bigint) {
        if (this.oracleMode !== "mock") return;
        await (await this.mockOracle!.setPrice(price)).wait();
        console.log(`mock oracle price restored to ${formatEther(price / 10n ** 18n)} frxUSD/sUSG`);
    }

    // --------------------------------------------------------------- summary

    async record(scenario: string, action: string, caller: string, tx: ContractTransactionResponse) {
        const receipt = await tx.wait();
        const events: MorphoStep["events"] = [];
        for (const log of receipt!.logs) {
            if (log.address.toLowerCase() !== MORPHO_BLUE.toLowerCase()) continue;
            let parsed;
            try {
                parsed = this.morpho.interface.parseLog({topics: [...log.topics], data: log.data});
            } catch {
                continue;
            }
            if (!parsed) continue;
            const args: Record<string, string> = {};
            parsed.fragment.inputs.forEach((input, i) => {
                args[input.name] = parsed!.args[i].toString();
            });
            events.push({name: parsed.name, args});
        }
        this.steps.push({scenario, action, caller: this.label(caller), block: receipt!.blockNumber, tx: receipt!.hash, events});
    }
}
