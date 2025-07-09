import {depositCurveLP} from "../actions/depositCurveLP";
import {depositStakeDao} from "../actions/depositStakeDao";
import {depositLlamaLend} from "../actions/depositLlamaLend";
import {withdrawCurveLP} from "../actions/withdrawCurveLP";
import {withdrawStakeDao} from "../actions/withdrawStakeDao";
import {depositCurveGauge} from "../actions/depositCurveGauge";
import {withdrawCurveGauge} from "../actions/withdrawCurveGauge";
import {crvUSD} from "defi-resources/build/ressources/erc20/common";
import {PointsContext} from "../contexts/PointsContext";
import {mappingMethod} from "./userActionGenerator";

export async function executeGeneratedActions(context: PointsContext): Promise<void> {
    try {
        const user1 = context.getUser1();
        const user2 = context.getUser2();
        if (!user1 || !user2) {
            throw new Error("Users not initialized. Call initUsers first.");
        }

        const lpToken0 = await depositCurveLP(mappingMethod("USDe_USDC", "depositCurveLP"), BigInt(10 ** 20), BigInt(100000000), user1);

        await depositCurveGauge(mappingMethod("USDe_USDC", "depositCurveGauge"), lpToken0, user1, BigInt(100000000));

        await context.advanceTime(12);

        await withdrawCurveGauge(mappingMethod("USDe_USDC", "withdrawCurveGauge"), user1, BigInt(1000000));

        await context.transferPosition(mappingMethod("USDe_USDC", "transferPosition"), user1, user2.address, BigInt(5000000));

        const lpToken1 = await depositCurveLP(mappingMethod("USDC_crvUSD", "depositCurveLP"), BigInt(1000000), BigInt(1e19), user1);

        await depositStakeDao(lpToken1, mappingMethod("USDC_crvUSD", "depositStakeDao"), user1, BigInt(1000000));

        await context.advanceTime(30);

        const lpToken2 = await depositCurveLP(mappingMethod("USDT_crvUSD", "depositCurveLP"), BigInt(10000000), BigInt(1e19), user2);

        await depositStakeDao(lpToken2, mappingMethod("USDT_crvUSD", "depositStakeDao"), user2, BigInt(1e18));

        await withdrawStakeDao(mappingMethod("USDT_crvUSD", "withdrawStakeDao"), user2, BigInt(500000));

        await context.transferPosition(mappingMethod("USDT_crvUSD", "transferPosition"), user2, user1.address, BigInt(1000000));

        await depositLlamaLend(mappingMethod("CRV_USD", "depositLlamaLend"), crvUSD, user2, 1000000, BigInt(1000000));

        await context.advanceTime(30);

        await withdrawStakeDao(mappingMethod("USDT_crvUSD", "withdrawStakeDao"), user2, BigInt(2000000));

        const lpBalance = await lpToken2.balanceOf(user2);
        await withdrawCurveLP(mappingMethod("USDT_crvUSD", "withdrawCurveLP"), lpBalance, user2);
    } catch (error) {
        throw error;
    }
}
