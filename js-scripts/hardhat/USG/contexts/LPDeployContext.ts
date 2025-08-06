import {ethers} from "hardhat";
import {IERC20Metadata, ICurveStableSwapNG, ICurveCryptoSwap} from "../../../../typechain-types";
import {BaseContext} from "./BaseContext";
import {AddressLike, BigNumberish, MaxUint256, parseUnits, ZeroAddress} from "ethers";
import {WStablesContext} from "./WStableContext";
import {commonERC20} from "defi-resources";

export type StableLP = {
    [name: string]: ICurveStableSwapNG;
};

export class LpDeployContext {
    stableLp: StableLP = {};
    tanLP?: ICurveCryptoSwap;

    async deployAllTangentLps(baseContext: BaseContext, wStableContext: WStablesContext) {
        const amount = 500_000;
        const USG_USDC = "USG-USDC";
        const USGC = "USGC";

        this.stableLp[USG_USDC] = await this.deployStableLP(
            baseContext,
            USG_USDC,
            USGC,
            [baseContext.coins.USDC, baseContext.USG],
            [amount, amount],
            "500",
            "1000000",
            "0",
            "866",
            "0"
        );

        const USG_wfrxUSD = "USG-wfrxUSD";
        const tgFrxUSD = "tgFrxUSD";
        this.stableLp[USG_wfrxUSD] = await this.deployStableLP(
            baseContext,
            USG_wfrxUSD,
            tgFrxUSD,
            [wStableContext.wStable.wfrxUSD, baseContext.USG],
            [amount, amount],
            "500",
            "1000000",
            "0",
            "866",
            "0"
        );

        this.tanLP = await this.deploy_TAN_ETH_LP(baseContext);

        // const USG_wcrvUSD = "USG-wcrvUSD";
        // const tgCrvUSD = "tgCrvUSD";
        // this.stableLp[USG_wcrvUSD] = await this.deployStableLP(
        //     baseContext,
        //     USG_wcrvUSD,
        //     tgCrvUSD,
        //     [wStableContext.wStable.wcrvUSD, baseContext.USG],
        //     [amount, amount],
        //     "5000",
        //     "100000000",
        //     "0",
        //     "866",
        //     "0"
        // );

        // const USG_wUSDe = "USG-wUSDe";
        // const USGe = "USGe";
        // this.stableLp[USG_wUSDe] = await this.deployStableLP(
        //     baseContext,
        //     USG_wUSDe,
        //     USGe,
        //     [wStableContext.wStable.wUSDe, baseContext.USG],
        //     [amount, amount],
        //     "5000",
        //     "100000000",
        //     "0",
        //     "866",
        //     "0"
        // );

        // const USG_wDOLA = "USG-wDOLA";
        // const tgDOLA = "tgDOLA";
        // this.stableLp[USG_wDOLA] = await this.deployStableLP(
        //     baseContext,
        //     USG_wDOLA,
        //     tgDOLA,
        //     [wStableContext.wStable.wDOLA, baseContext.USG],
        //     [amount, amount],
        //     "5000",
        //     "100000000",
        //     "0",
        //     "866",
        //     "0"
        // );

        // const USG_wUSR = "USG-wUSR";
        // const tgUSR = "tgUSR";
        // this.stableLp[USG_wUSR] = await this.deployStableLP(
        //     baseContext,
        //     USG_wUSR,
        //     tgUSR,
        //     [wStableContext.wStable.wUSR, baseContext.USG],
        //     [amount, amount],
        //     "5000",
        //     "100000000",
        //     "0",
        //     "866",
        //     "0"
        // );
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

    async deploy_TAN_ETH_LP(baseContext: BaseContext) {
        const deployer = baseContext.owner;
        const curveStableSwapFactory = await ethers.getContractAt("ICurveCryptoSwapFactoryNG", "0x98EE851a00abeE0d95D08cF4CA2BdCE32aeaAF7F");

        const poolCount = await curveStableSwapFactory.pool_count();
        const lpCreationTx = await curveStableSwapFactory
            .connect(deployer)
            .deploy_pool(
                "TAN",
                "TAN",
                [commonERC20.WETH, baseContext.TAN],
                0,
                400000,
                145000000000000,
                26000000,
                45000000,
                230000000000000,
                2000000000000,
                146000000000000,
                866,
                6006006006000
            );
        await lpCreationTx.wait();

        const lp = await ethers.getContractAt("ICurveCryptoSwap", await curveStableSwapFactory.pool_list(poolCount));
        const coin0 = await ethers.getContractAt("ERC20", commonERC20.WETH);
        const coin1 = await ethers.getContractAt("ERC20", baseContext.TAN);
        await coin0.connect(deployer).approve(lp, MaxUint256);
        await coin1.connect(deployer).approve(lp, MaxUint256);

        await lp.connect(deployer)["add_liquidity(uint256[2],uint256)"]([parseUnits("200", await coin0.decimals()), parseUnits("3330000", await coin1.decimals())], 0);

        return lp;
    }

    async _usersApproveLp(baseContext: BaseContext, coins: IERC20Metadata[], lp: AddressLike) {
        const users = baseContext.users;

        for (let i = 0; i < users.length; i++) {
            const user = users[i];
            await coins[0].connect(user).approve(lp, MaxUint256);
            await coins[1].connect(user).approve(lp, MaxUint256);
        }
    }
}
