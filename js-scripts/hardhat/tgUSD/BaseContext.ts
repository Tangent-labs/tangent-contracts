import {ethers} from "hardhat";

import {commonERC20, convexContracts, convexERC20, curveLp, stakeDaoERC20} from "convergence-defi-tools";

import {MainSetup} from "../Main.setup";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {Addressable, AddressLike, BigNumberish, MaxUint256, parseEther, parseUnits, ZeroAddress} from "ethers";
import {
    ControlTower,
    ICurveStableSwapFactoryNG,
    ICurveStableSwapNG,
    IERC20,
    IRCalculator,
    RewardAccumulator,
    StablePriceOracleParams,
    TgUSD,
    Zapper,
} from "../../../typechain-types";
export type StableLP = {
    [name: string]: ICurveStableSwapNG;
};
export class BaseContext extends MainSetup {
    owner!: HardhatEthersSigner;
    feeTreso!: HardhatEthersSigner;

    controlTower!: ControlTower;

    tgUSD!: TgUSD;
    zapper!: Zapper;
    rewardAccumulator!: RewardAccumulator;
    irCalculator!: IRCalculator;

    stableLp: StableLP = {};
    coins: {[name: string]: IERC20} = {};

    async deployContracts1() {
        const l0EndpointAddress = "0x1a44076050125825900e736c501f859c50fE728c";
        // TODO To change
        const l0Delegate = "0x1a44076050125825900e736c501f859c50fE728c";

        this.owner = this.users[0];
        this.feeTreso = this.users[1];

        const ControlTowerFactory = await ethers.getContractFactory("ControlTower");
        this.controlTower = await ControlTowerFactory.deploy(this.owner, this.feeTreso);
        await this.controlTower.waitForDeployment();

        const TgUSDFactory = await ethers.getContractFactory("TgUSD");
        this.tgUSD = await TgUSDFactory.deploy("Tangent USD", "tgUSD", l0EndpointAddress, l0Delegate, this.owner, this.controlTower);
        await this.tgUSD.waitForDeployment();

        const ZapperFactory = await ethers.getContractFactory("Zapper");
        this.zapper = await ZapperFactory.deploy(this.owner, this.controlTower, this.tgUSD);
        await this.zapper.waitForDeployment();

        const RewardAccumulatorFactory = await ethers.getContractFactory("RewardAccumulator");
        this.rewardAccumulator = await RewardAccumulatorFactory.deploy(this.owner, this.controlTower, this.feeTreso);
        await this.rewardAccumulator.waitForDeployment();
    }

    async deployStableLP(
        name: string,
        coins: IERC20[],
        amounts: BigNumberish[],
        A: BigNumberish,
        fee: BigNumberish,
        _offpeg_fee_multiplier: BigNumberish,
        _ma_exp_time: BigNumberish,
        implemId: BigNumberish
    ) {
        const curveStableSwapFactory = await ethers.getContractAt("ICurveStableSwapFactoryNG", "0x6A8cbed756804B16E05E741eDaBd5cB544AE21bf");

        const poolCount = await curveStableSwapFactory.pool_count();
        console.log(poolCount);
        const lpCreationTx = await curveStableSwapFactory
            .connect(this.owner)
            .deploy_plain_pool(
                name,
                name,
                coins,
                A,
                fee,
                _offpeg_fee_multiplier,
                _ma_exp_time,
                implemId,
                [0, 0],
                ["0x00000000", "0x00000000"],
                [ZeroAddress, ZeroAddress]
            );
        await lpCreationTx.wait();

        const lp = await ethers.getContractAt("ICurveStableSwapNG", await curveStableSwapFactory.pool_list(poolCount));

        this.stableLp[name] = lp;

        await this.coins.usdc.connect(this.owner).approve(lp, MaxUint256);
        await this.tgUSD.connect(this.owner).approve(lp, MaxUint256);

        await lp.connect(this.owner)["add_liquidity(uint256[],uint256)"](amounts, 0);
    }

    async deployContracts2(tgUSDOracle: AddressLike) {
        const IRCalculatorFactory = await ethers.getContractFactory("IRCalculator");
        this.irCalculator = await IRCalculatorFactory.deploy(this.owner, tgUSDOracle);
        await this.irCalculator.waitForDeployment();
    }

    async setUpERC20() {
        this.coins["usdc"] = await ethers.getContractAt("IERC20", commonERC20.USDC);
        this.coins["crvUSD_USDC"] = await ethers.getContractAt("IERC20", curveLp.CRVUSD_USDC);

        await this.giveTokens(this.users, [{address: await this.tgUSD.getAddress(), decimals: 18, isVyper: false, slotBalance: 5, amount: 1_000_000}]);
    }

    async approveCurveLP(lp: string) {
        const curveLP = await ethers.getContractAt("ICurveStableSwapNG", lp);
        const coin0 = await ethers.getContractAt("IERC20", await curveLP.coins(0));
        const coin1 = await ethers.getContractAt("IERC20", await curveLP.coins(1));

        for (let i = 0; i < this.users.length; i++) {
            const user = this.users[i];
            await coin0.connect(user).approve(lp, MaxUint256);
            await coin1.connect(user).approve(lp, MaxUint256);
        }
    }
}
