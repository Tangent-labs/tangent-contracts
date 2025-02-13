import {LiquidationContext} from "../contexts/LiquidationContext";

async function main() {
    const liquidationContext = new LiquidationContext();
    await liquidationContext.doDeploy();
    await liquidationContext.doDepositAndBorrow();
    console.info("\x1b[32m%s\x1b[0m", "Liquidation context is setup !");

    await liquidationContext.testChainView();
    console.info("\x1b[32m%s\x1b[0m", "testChainView OK");

    await liquidationContext.unbalanceContext();
    console.info("\x1b[32m%s\x1b[0m", "unbalanceContext OK");
}
main();
