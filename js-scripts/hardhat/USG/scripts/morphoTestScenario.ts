import {ethers} from "hardhat";
import {
    morphoSeedLoanLiquidity,
    morphoSupplyCollateral,
    morphoWithdrawCollateral,
    morphoBorrow,
    morphoOpenMaxBorrowPosition,
    morphoLiquidatePartial,
    morphoLiquidateFull,
    morphoRestoreOraclePrice,
} from "../actions/morphoActions";

/* Living example for the Morpho points integration — the reference scenario suite used to
   validate the indexer, written with the composable actions from morphoActions.ts.

   Run it on a fork (npm run hh-node), then follow tangent-indexer/docs/morpho-points-testing.md:
   index, then `npx tsx src/scripts/utils/check_morpho_context.ts` asserts every expected
   effect below. For the full ground-truth comparison start from a FRESH fork + DB; on a reused
   fork the checker still validates everything in chain-only mode.

   npm run morpho-example-scenario */

main();
export async function main() {
    try {
        const [, , user2, user3, user4, user5, user6, user7] = await ethers.getSigners();

        // frxUSD lending liquidity so the borrow legs work (the supply side is NOT tracked by points)
        await morphoSeedLoanLiquidity(200000);

        // 1. Simple flow — open segment of 10000, then 6000, then closed (balance back to 0)
        await morphoSupplyCollateral(user2, 10000);
        await morphoWithdrawCollateral(user2, 4000);
        await morphoWithdrawCollateral(user2, 6000);

        // 2. onBehalf — the 5000 sUSG belong to user4 (the indexer must credit onBehalf, never the caller)
        await morphoSupplyCollateral(user3, 5000, user4);
        await morphoWithdrawCollateral(user4, 1000); // user4 ends at 4000

        // 3. Leverage loop — user5 ends at 19600 collateral; Borrow events must not affect collateral
        await morphoSupplyCollateral(user5, 10000);
        await morphoBorrow(user5, 6000);
        await morphoSupplyCollateral(user5, 6000); // simulated frxUSD -> sUSG swap
        await morphoBorrow(user5, 3600);
        await morphoSupplyCollateral(user5, 3600);

        // 4. Partial liquidation — Liquidate emits seizedAssets, user6's balance shrinks by it
        //    (no WithdrawCollateral is emitted: the burn comes from the Liquidate event alone)
        await morphoOpenMaxBorrowPosition(user6, 10000);
        await morphoLiquidatePartial(user6);

        // 5. Full seizure with bad debt — user7's balance must end at exactly 0
        await morphoOpenMaxBorrowPosition(user7, 10000);
        await morphoLiquidateFull(user7);

        await morphoRestoreOraclePrice();
    } catch (error) {
        throw error;
    }
}
