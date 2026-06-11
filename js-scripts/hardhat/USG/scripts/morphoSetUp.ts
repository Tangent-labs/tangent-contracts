import {network} from "hardhat";
import {MorphoContext} from "../contexts/MorphoContext";

// Sets up the sUSG/frxUSD Morpho Blue market on the local fork and replays every event
// type the points indexer consumes (SupplyCollateral / WithdrawCollateral / Liquidate).
//
// Env knobs:
//   MORPHO_SCENARIOS=simple,onbehalf,loop,liquidation,baddebt  (default: all)
//   MORPHO_MOCK_ORACLE=1  force the mock oracle (bytecode injected at the real oracle address: the market id does NOT change)
async function main() {
    await network.provider.send("evm_mine", []);

    const scenarios = (process.env.MORPHO_SCENARIOS || "simple,onbehalf,loop,liquidation,baddebt")
        .split(",")
        .map((s) => s.trim().toLowerCase())
        .filter(Boolean);
    const enabled = (name: string) => scenarios.includes(name);

    const context = new MorphoContext();
    await context.setup();
    console.info("\x1b[32m%s\x1b[0m", `Morpho market ready (${context.oracleMode} oracle): ${context.marketId}`);

    await context.seedLoanLiquidity();
    const initialPrice = await context.oraclePrice();

    if (enabled("simple")) await context.scenarioSimple();
    if (enabled("onbehalf")) await context.scenarioOnBehalf();
    if (enabled("loop")) await context.scenarioLoop();

    if (enabled("liquidation") || enabled("baddebt")) {
        await context.fundLiquidator();
        if (enabled("liquidation")) await context.openMaxBorrowPosition(context.accounts.userE, 10_000n * 10n ** 18n, "liquidation");
        if (enabled("baddebt")) await context.openMaxBorrowPosition(context.accounts.userF, 10_000n * 10n ** 18n, "bad-debt");
        await context.pushUtilization();
        if (enabled("liquidation")) await context.scenarioLiquidation();
        if (enabled("baddebt")) await context.scenarioBadDebt();
        await context.restoreMockPrice(initialPrice);
    }

    console.info("\x1b[32m%s\x1b[0m", "Morpho context is setup !");

    await network.provider.send("evm_setAutomine", [false]);
}

main()
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    })
    .finally(() => {
        process.exit();
    });
