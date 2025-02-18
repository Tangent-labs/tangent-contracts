import {ethers} from "hardhat";
import {IERC20Metadata, IAggregatorStablePriceV3, ICurveStableSwapNG, IPriceOracle} from "../../../../typechain-types";
import {BaseContext} from "./BaseContext";
import {BigNumberish, MaxUint256, parseEther, parseUnits, ZeroAddress} from "ethers";

export type StableLP = {
    [name: string]: ICurveStableSwapNG;
};

export class LpDeployContext {
    stableLp: StableLP = {};

    async deployAllTgUSDLps(baseContext: BaseContext) {
        const tgUSD_USDC = "tgUSD-USDC";
        this.stableLp[tgUSD_USDC] = await this.deployStableLP(
            baseContext,
            tgUSD_USDC,
            "tgUSDC",
            [baseContext.coins.USDC, baseContext.tgUSD],
            [1_000_000, 1_000_000],
            "5000",
            "100000000",
            "0",
            "866",
            "0"
        );

        const tgUSD_frxUSD = "tgUSD-frxUSD";
        this.stableLp[tgUSD_frxUSD] = await this.deployStableLP(
            baseContext,
            tgUSD_frxUSD,
            "tgFrxUSD",
            [baseContext.coins.frxUSD, baseContext.tgUSD],
            [1_000_000, 1_000_000],
            "5000",
            "100000000",
            "0",
            "866",
            "0"
        );
    }

    async deployStableLP(
        baseContext: BaseContext,
        name: string,
        symbol: string,
        coins: IERC20Metadata[],
        amounts: BigNumberish[],
        A: BigNumberish,
        fee: BigNumberish,
        _offpeg_fee_multiplier: BigNumberish,
        _ma_exp_time: BigNumberish,
        implemId: BigNumberish
    ) {
        const deployer = baseContext.owner;
        const curveStableSwapFactory = await ethers.getContractAt("ICurveStableSwapFactoryNG", "0x6A8cbed756804B16E05E741eDaBd5cB544AE21bf");

        const poolCount = await curveStableSwapFactory.pool_count();
        const lpCreationTx = await curveStableSwapFactory
            .connect(deployer)
            .deploy_plain_pool(name, symbol, coins, A, fee, _offpeg_fee_multiplier, _ma_exp_time, implemId, [0, 0], ["0x00000000", "0x00000000"], [ZeroAddress, ZeroAddress]);
        await lpCreationTx.wait();

        const lp = await ethers.getContractAt("ICurveStableSwapNG", await curveStableSwapFactory.pool_list(poolCount));

        await coins[0].connect(deployer).approve(lp, MaxUint256);
        await coins[1].connect(deployer).approve(lp, MaxUint256);

        await lp
            .connect(deployer)
            ["add_liquidity(uint256[],uint256)"]([parseUnits(amounts[0].toString(), await coins[0].decimals()), parseUnits(amounts[1].toString(), await coins[1].decimals())], 0);

        return lp;
    }
}
