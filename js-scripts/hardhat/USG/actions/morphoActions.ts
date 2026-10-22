import {parseEther} from "ethers";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {MorphoContext} from "../contexts/MorphoContext";

/* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
            MORPHO BLUE (sUSG/frxUSD market)
=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=

Composable actions for generated-actions.ts, e.g.:

    const [, , user2, user3] = await ethers.getSigners();
    await morphoSeedLoanLiquidity(200000);
    await morphoSupplyCollateral(user2, 10000);
    await morphoBorrow(user2, 5000);
    await morphoSupplyCollateral(user3, 5000, user2);   // user3 supplies on behalf of user2
    await morphoWithdrawCollateral(user2, 1000);
    await morphoLiquidatePartial(user2);                 // pushes the market until liquidatable

The first action lazily sets up the context: re-creates the prod sUSG/frxUSD market on the
fork (same deterministic market id as mainnet, mock oracle bytecode injected at the real
oracle address if needed) and reuses it on reruns. Amounts are token units (18 decimals).
The indexer-side checker works without the summary file (chain-only mode), the summary
just adds the step-by-step ground truth. */

let context: MorphoContext | null = null;
let initialOraclePrice: bigint | null = null;

export const getMorphoContext = async (): Promise<MorphoContext> => {
    if (!context) {
        context = new MorphoContext();
        await context.setup();
        initialOraclePrice = await context.oraclePrice();
    }
    return context;
};

/**
 * Supply sUSG as collateral (funds the caller and approves automatically).
 * @param user The signer paying the collateral
 * @param amount Amount of sUSG, token units
 * @param onBehalf Optional beneficiary of the position (defaults to user — the indexer must always credit onBehalf)
 */
export const morphoSupplyCollateral = async (user: HardhatEthersSigner, amount: number, onBehalf?: HardhatEthersSigner) => {
    const ctx = await getMorphoContext();
    const assets = parseEther(amount.toString());
    await ctx.fundCollateral(user, assets);
    const beneficiary = (onBehalf ?? user).address;
    const tx = await ctx.morpho.connect(user).supplyCollateral(ctx.marketParams, assets, beneficiary, "0x");
    await ctx.record("actions", `supplyCollateral ${amount} sUSG onBehalf ${ctx.label(beneficiary)}`, user.address, tx);
};

/**
 * Withdraw sUSG collateral from the user's own position.
 * @param amount Amount of sUSG, token units
 * @param receiver Optional receiver of the tokens (defaults to user)
 */
export const morphoWithdrawCollateral = async (user: HardhatEthersSigner, amount: number, receiver?: HardhatEthersSigner) => {
    const ctx = await getMorphoContext();
    const tx = await ctx.morpho.connect(user).withdrawCollateral(ctx.marketParams, parseEther(amount.toString()), user.address, (receiver ?? user).address);
    await ctx.record("actions", `withdrawCollateral ${amount} sUSG`, user.address, tx);
};

/**
 * Supply frxUSD on the lending side so that borrows are possible.
 * @param amount Amount of frxUSD, token units
 */
export const morphoSeedLoanLiquidity = async (amount: number = 200000) => {
    const ctx = await getMorphoContext();
    await ctx.seedLoanLiquidity(parseEther(amount.toString()));
};

/**
 * Borrow frxUSD against the user's collateral.
 * @param amount Amount of frxUSD, token units
 */
export const morphoBorrow = async (user: HardhatEthersSigner, amount: number) => {
    const ctx = await getMorphoContext();
    const assets = parseEther(amount.toString());
    const tx = await ctx.morpho.connect(user).borrow(ctx.marketParams, assets, 0n, user.address, user.address);
    await ctx.record("actions", `borrow ${amount} frxUSD`, user.address, tx);
};

/**
 * Repay frxUSD debt (funds the user automatically).
 * @param amount Amount of frxUSD, token units
 */
export const morphoRepay = async (user: HardhatEthersSigner, amount: number) => {
    const ctx = await getMorphoContext();
    const assets = parseEther(amount.toString());
    await ctx.fundLoanToken(user, assets);
    const tx = await ctx.morpho.connect(user).repay(ctx.marketParams, assets, 0n, user.address, "0x");
    await ctx.record("actions", `repay ${amount} frxUSD`, user.address, tx);
};

/**
 * Open a position at 99.8% of max borrow — liquidatable after the first price drop / interest accrual.
 * @param collateralAmount Amount of sUSG collateral, token units
 */
export const morphoOpenMaxBorrowPosition = async (user: HardhatEthersSigner, collateralAmount: number) => {
    const ctx = await getMorphoContext();
    await ctx.seedLoanLiquidity(parseEther((collateralAmount * 2).toString()));
    await ctx.openMaxBorrowPosition(user, parseEther(collateralAmount.toString()), "actions");
};

/**
 * Partially liquidate the borrower (repays half the borrow shares -> Liquidate event, no bad debt).
 * Pushes the market (mock oracle price drops / time jumps) until the position is liquidatable.
 */
export const morphoLiquidatePartial = async (borrower: HardhatEthersSigner) => {
    const ctx = await getMorphoContext();
    await ctx.pushUtilization(); // real-oracle mode: interest must accrue fast enough to go underwater
    await ctx.fundLiquidator();
    const liquidator = ctx.accounts.liquidator;
    const morpho = ctx.morpho.connect(liquidator);

    const tryLiquidate = async () => {
        const position = await ctx.morpho.position(ctx.marketId, borrower.address);
        try {
            await morpho.liquidate.staticCall(ctx.marketParams, borrower.address, 0n, position.borrowShares / 2n, "0x");
            return true;
        } catch {
            return false;
        }
    };
    await ctx.makeLiquidatable(borrower, tryLiquidate, 7 * 86400, 60, "actions-liquidation");

    const position = await ctx.morpho.position(ctx.marketId, borrower.address);
    const tx = await morpho.liquidate(ctx.marketParams, borrower.address, 0n, position.borrowShares / 2n, "0x");
    await ctx.record("actions", `liquidate ${ctx.label(borrower.address)} (repay half the borrow shares)`, liquidator.address, tx);
};

/**
 * Fully liquidate the borrower (seizes all collateral -> Liquidate event with badDebtAssets > 0 if underwater enough).
 */
export const morphoLiquidateFull = async (borrower: HardhatEthersSigner) => {
    const ctx = await getMorphoContext();
    await ctx.pushUtilization(); // real-oracle mode: interest must accrue fast enough to go underwater
    await ctx.fundLiquidator();
    const liquidator = ctx.accounts.liquidator;
    const morpho = ctx.morpho.connect(liquidator);

    const tryLiquidate = async () => {
        const position = await ctx.morpho.position(ctx.marketId, borrower.address);
        try {
            await morpho.liquidate.staticCall(ctx.marketParams, borrower.address, position.collateral, 0n, "0x");
            return true;
        } catch {
            return false;
        }
    };
    await ctx.makeLiquidatable(borrower, tryLiquidate, 30 * 86400, 36, "actions-bad-debt");

    const position = await ctx.morpho.position(ctx.marketId, borrower.address);
    const tx = await morpho.liquidate(ctx.marketParams, borrower.address, position.collateral, 0n, "0x");
    await ctx.record("actions", `liquidate ${ctx.label(borrower.address)} (seize full collateral)`, liquidator.address, tx);
};

/** Restore the mock oracle to its initial price (no-op in real-oracle mode) — call after liquidations. */
export const morphoRestoreOraclePrice = async () => {
    const ctx = await getMorphoContext();
    if (initialOraclePrice !== null) {
        await ctx.restoreMockPrice(initialOraclePrice);
    }
};
