import {depositCurveLP} from "../actions/depositCurveLP";
import {depositStakeDao} from "../actions/depositStakeDao";
import {depositLlamaLend} from "../actions/depositLlamaLend";
import {withdrawCurveLP} from "../actions/withdrawCurveLP";
import {withdrawStakeDao} from "../actions/withdrawStakeDao";
import {depositCurveGauge} from "../actions/depositCurveGauge";
import {withdrawCurveGauge} from "../actions/withdrawCurveGauge";
import {PointsContext} from "../contexts/PointsContext";

export async function executeGeneratedActions(context: PointsContext): Promise<void> {
    try {
        const user1 = context.getUser1();
        const user2 = context.getUser2();
        if (!user1 || !user2) {
            throw new Error("Users not initialized. Call initUsers first.");
        }
        await depositCurveLP("USDe_USDC", user1, BigInt(100000000));

        await depositCurveGauge("USDe_USDC", user1, BigInt(100000000));

        await context.advanceTime(12);

        await withdrawCurveGauge("USDe_USDC", user1, BigInt(1000000));

        await context.transferPosition("USDe_USDC", user1, user2.address, BigInt(5000000));

        await depositCurveLP("USDC_crvUSD", user1, BigInt(1e19));

        await depositStakeDao("USDC_crvUSD", user1, BigInt(1000000));

        await context.advanceTime(30);

        await depositCurveLP("USDT_crvUSD", user2, BigInt(1e19));

        await depositStakeDao("USDT_crvUSD", user2, BigInt(1e18));

        await withdrawStakeDao("USDT_crvUSD", user2, BigInt(500000));

        await context.transferPosition("USDT_crvUSD", user2, user1.address, BigInt(1000000));

        await depositLlamaLend("LLAMALEND_sDOLA_crvUSD", user2, 1000000, BigInt(1000000));

        await context.advanceTime(30);

        await withdrawStakeDao("USDT_crvUSD", user2, BigInt(2000000));

        await withdrawCurveLP("USDT_crvUSD", BigInt(2000000), user2);
    } catch (error) {
        throw error;
    }
}
