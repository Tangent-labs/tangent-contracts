import {ethers} from "hardhat";
import {IERC20Metadata, ICurveStableSwapNG} from "../../../../typechain-types";
import {BaseContext} from "./BaseContext";
import {BigNumberish, MaxUint256, parseUnits, ZeroAddress} from "ethers";
import {WStablesContext} from "./WStableContext";

export type StableLP = {
    [name: string]: ICurveStableSwapNG;
};

export class LpDeployContext {
    stableLp: StableLP = {};

    async deployAllTgUSDLps(baseContext: BaseContext, wStableContext: WStablesContext) {
        const amount = 500_000;
        const tgUSD_USDC = "tgUSD-USDC";
        const tgUSDC = "tgUSDC";

        this.stableLp[tgUSD_USDC] = await this.deployStableLP(
            baseContext,
            tgUSD_USDC,
            tgUSDC,
            [baseContext.coins.USDC, baseContext.tgUSD],
            [amount, amount],
            "5000",
            "100000000",
            "0",
            "866",
            "0"
        );

        const tgUSD_wfrxUSD = "tgUSD-wfrxUSD";
        const tgFrxUSD = "tgFrxUSD";
        this.stableLp[tgUSD_wfrxUSD] = await this.deployStableLP(
            baseContext,
            tgUSD_wfrxUSD,
            tgFrxUSD,
            [wStableContext.wStable.wfrxUSD, baseContext.tgUSD],
            [amount, amount],
            "5000",
            "100000000",
            "0",
            "866",
            "0"
        );

        const tgUSD_wcrvUSD = "tgUSD-wcrvUSD";
        const tgCrvUSD = "tgCrvUSD";
        this.stableLp[tgUSD_wcrvUSD] = await this.deployStableLP(
            baseContext,
            tgUSD_wcrvUSD,
            tgCrvUSD,
            [wStableContext.wStable.wcrvUSD, baseContext.tgUSD],
            [amount, amount],
            "5000",
            "100000000",
            "0",
            "866",
            "0"
        );

        const tgUSD_wUSDe = "tgUSD-wUSDe";
        const tgUSDe = "tgUSDe";
        this.stableLp[tgUSD_wUSDe] = await this.deployStableLP(
            baseContext,
            tgUSD_wUSDe,
            tgUSDe,
            [wStableContext.wStable.wUSDe, baseContext.tgUSD],
            [amount, amount],
            "5000",
            "100000000",
            "0",
            "866",
            "0"
        );

        const tgUSD_wDOLA = "tgUSD-wDOLA";
        const tgDOLA = "tgDOLA";
        this.stableLp[tgUSD_wDOLA] = await this.deployStableLP(
            baseContext,
            tgUSD_wDOLA,
            tgDOLA,
            [wStableContext.wStable.wDOLA, baseContext.tgUSD],
            [amount, amount],
            "5000",
            "100000000",
            "0",
            "866",
            "0"
        );

        const tgUSD_wUSR = "tgUSD-wUSR";
        const tgUSR = "tgUSR";
        this.stableLp[tgUSD_wUSR] = await this.deployStableLP(
            baseContext,
            tgUSD_wUSR,
            tgUSR,
            [wStableContext.wStable.wUSR, baseContext.tgUSD],
            [amount, amount],
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

        await this._usersApproveLp(baseContext, coins, lp);

        return lp;
    }

    async _usersApproveLp(baseContext: BaseContext, coins: IERC20Metadata[], lp: ICurveStableSwapNG) {
        const users = baseContext.users;

        for (let i = 0; i < users.length; i++) {
            const user = users[i];
            await coins[0].connect(user).approve(lp, MaxUint256);
            await coins[1].connect(user).approve(lp, MaxUint256);
        }
    }
}
