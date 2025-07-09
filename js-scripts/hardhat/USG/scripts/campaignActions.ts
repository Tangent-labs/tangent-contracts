import {depositCurveLP} from "../actions/depositCurveLP";
import {depositStakeDao} from "../actions/depositStakeDao";
import {depositLlamaLend} from "../actions/depositLlamaLend";
import {withdrawCurveLP} from "../actions/withdrawCurveLP";
import {withdrawStakeDao} from "../actions/withdrawStakeDao";
import {depositCurveGauge} from "../actions/depositCurveGauge";
import {withdrawCurveGauge} from "../actions/withdrawCurveGauge";
import {CRV_DUO_USDC_crvUSD, CRV_DUO_USDe_USDC, CRV_DUO_USDT_crvUSD} from "defi-resources/build/ressources/lps/curve";
import {SDT_crvUSD_USDC_STRAT, SDT_crvUSD_USDT_GAUGE, SDT_crvUSD_USDT_STRAT} from "defi-resources/build/ressources/erc20/stakeDao";
import {CURVE_USDe_USDC_GAUGE} from "defi-resources/build/ressources/erc20/curve";
import {CRV_USD_LLAMA_VAULT} from "defi-resources/build/ressources/erc20/llamalend";
import {PointsContext} from "../contexts/PointsContext";
import {crvUSD} from "defi-resources/build/ressources/erc20/common";

export async function executeGeneratedActions(context: PointsContext): Promise<void> {
    try {
        const user1 = context.getUser1();
        const user2 = context.getUser2();
        if (!user1 || !user2) {
            throw new Error("Users not initialized. Call initUsers first.");
        }

        const lpToken0 = await depositCurveLP(CRV_DUO_USDe_USDC, BigInt(10 ** 20), BigInt(100000000), user1);

        await depositCurveGauge(CURVE_USDe_USDC_GAUGE, lpToken0, user1, BigInt(100000000));

        await context.advanceTime(12);

        await withdrawCurveGauge(CURVE_USDe_USDC_GAUGE, user1, BigInt(1000000));

        await context.transferPosition(CRV_DUO_USDe_USDC, user1, user2.address, BigInt(5000000));

        const lpToken1 = await depositCurveLP(CRV_DUO_USDC_crvUSD, BigInt(1000000), BigInt(1e19), user1);

        await depositStakeDao(lpToken1, SDT_crvUSD_USDC_STRAT, user1, BigInt(1000000));

        await context.advanceTime(30);

        const lpToken2 = await depositCurveLP(CRV_DUO_USDT_crvUSD, BigInt(10000000), BigInt(1e19), user2);

        await depositStakeDao(lpToken2, SDT_crvUSD_USDT_STRAT, user2, BigInt(1e18));

        await withdrawStakeDao(SDT_crvUSD_USDT_STRAT, user2, BigInt(500000));

        await context.transferPosition(SDT_crvUSD_USDT_GAUGE, user2, user1.address, BigInt(1000000));

        await depositLlamaLend(CRV_USD_LLAMA_VAULT, crvUSD, user2, 1000000, BigInt(1000000));

        await context.advanceTime(30);

        await withdrawStakeDao(SDT_crvUSD_USDT_STRAT, user2, BigInt(2000000));

        const lpBalance = await lpToken2.balanceOf(user2);
        await withdrawCurveLP(CRV_DUO_USDT_crvUSD, lpBalance, user2);
    } catch (error) {
        throw error;
    }
}
