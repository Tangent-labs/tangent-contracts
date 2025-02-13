import {ethers} from "hardhat";

import {commonERC20, curveLp} from "convergence-defi-tools";

import {MainSetup} from "../../Main.setup";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {AddressLike, BigNumberish, MaxUint256, ZeroAddress} from "ethers";
import {
    ControlTower,
    ConvexCrvLPMarket,
    ConvexFxnLPMarket,
    ICurveStableSwapNG,
    IERC20,
    IPegKeeperRegulator,
    IPegKeeperV2,
    IRCalculator,
    IYearnV3Vault,
    LiquidatorProxy,
    MarketCreator,
    MarketNoSociabilization,
    RewardAccumulator,
    TgUSD,
    Zapper,
} from "../../../../typechain-types";
import {oracles} from "../../../../typechain-types/src/tgUSD";
export type StableLP = {
    [name: string]: ICurveStableSwapNG;
};
export class BaseContext extends MainSetup {
    owner!: HardhatEthersSigner;
    feeTreso!: HardhatEthersSigner;

    controlTower!: ControlTower;
    tgUSD!: TgUSD;
    sgUSD!: IYearnV3Vault;
    zapper!: Zapper;
    rewardAccumulator!: RewardAccumulator;
    liquidatorProxy!: LiquidatorProxy;
    irCalculator!: IRCalculator;
    marketCreator!: MarketCreator;

    pegKeeperRegulator!: IPegKeeperRegulator;
    pegKeeperTgUSD_USDC!: IPegKeeperV2;

    marketCvxCrvImplem!: ConvexCrvLPMarket;
    marketCvxFxnImplem!: ConvexFxnLPMarket;
    marketNoSociabilizationImplem!: MarketNoSociabilization;

    stableLp: StableLP = {};
    coins: {[name: string]: IERC20} = {};

    async deployContracts1() {
        const l0EndpointAddress = "0x1a44076050125825900e736c501f859c50fE728c";
        // TODO To change
        const l0Delegate = "0x1a44076050125825900e736c501f859c50fE728c";

        this.owner = this.users[0];
        this.feeTreso = this.users[1];

        this.controlTower = await (await ethers.getContractFactory("ControlTower")).deploy(this.owner, this.feeTreso);
        await this.controlTower.waitForDeployment();

        this.tgUSD = await (await ethers.getContractFactory("TgUSD")).deploy("Tangent USD", "tgUSD", l0EndpointAddress, l0Delegate, this.owner, this.controlTower);
        await this.tgUSD.waitForDeployment();

        await this.deploySgUSD();

        this.zapper = await (await ethers.getContractFactory("Zapper")).deploy(this.owner, this.controlTower, this.tgUSD);
        await this.zapper.waitForDeployment();

        this.rewardAccumulator = await (await ethers.getContractFactory("RewardAccumulator")).deploy(this.owner, this.controlTower);
        await this.rewardAccumulator.waitForDeployment();

        this.liquidatorProxy = await (await ethers.getContractFactory("LiquidatorProxy")).deploy(this.tgUSD);
        await this.liquidatorProxy.waitForDeployment();

        this.marketCvxCrvImplem = await (await ethers.getContractFactory("ConvexCrvLPMarket")).deploy();
        await this.marketCvxCrvImplem.waitForDeployment();
        this.marketCvxFxnImplem = await (await ethers.getContractFactory("ConvexFxnLPMarket")).deploy();
        await this.marketCvxFxnImplem.waitForDeployment();
        this.marketNoSociabilizationImplem = await (await ethers.getContractFactory("MarketNoSociabilization")).deploy();
        await this.marketNoSociabilizationImplem.waitForDeployment();

        await this.controlTower.connect(this.owner).toggleZapper(this.zapper);
    }

    async deploySgUSD() {
        const yearnVaultFactory = await ethers.getContractAt("IYearnVaultFactory", "0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F");
        await yearnVaultFactory.deploy_new_vault(this.tgUSD, "Staked tgUSD", "sgUSD", this.owner, 7 * 86400);

        const actualBlock = (await ethers.provider.getBlock("latest"))!.number;
        const createEvents = await yearnVaultFactory.queryFilter(yearnVaultFactory.filters.NewVault(), actualBlock - 1, actualBlock);

        this.sgUSD = await ethers.getContractAt("IYearnV3Vault", "0x" + createEvents[0].topics[1].slice(26));

        // Set deposit limit
        await this.sgUSD.add_role(this.owner, 256);
        // Set reward processor
        await this.sgUSD.add_role(this.owner, 32);
        // Set max number as maximum to deposit
        await this.sgUSD["set_deposit_limit(uint256)"](ethers.MaxUint256);
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
        const lpCreationTx = await curveStableSwapFactory
            .connect(this.owner)
            .deploy_plain_pool(name, name, coins, A, fee, _offpeg_fee_multiplier, _ma_exp_time, implemId, [0, 0], ["0x00000000", "0x00000000"], [ZeroAddress, ZeroAddress]);
        await lpCreationTx.wait();

        const lp = await ethers.getContractAt("ICurveStableSwapNG", await curveStableSwapFactory.pool_list(poolCount));

        this.stableLp[name] = lp;

        await this.coins.usdc.connect(this.owner).approve(lp, MaxUint256);
        await this.tgUSD.connect(this.owner).approve(lp, MaxUint256);

        await lp.connect(this.owner)["add_liquidity(uint256[],uint256)"](amounts, 0);
    }

    async deployContracts2(tgUSDOracle: AddressLike) {
        this.irCalculator = await (await ethers.getContractFactory("IRCalculator")).deploy(this.owner, this.controlTower, tgUSDOracle);
        await this.irCalculator.waitForDeployment();

        this.marketCreator = await (
            await ethers.getContractFactory("MarketCreator")
        ).deploy(
            this.owner,
            this.controlTower,
            this.tgUSD,
            this.irCalculator,
            this.rewardAccumulator,
            this.liquidatorProxy,
            this.marketCvxCrvImplem,
            this.marketCvxFxnImplem,
            this.marketNoSociabilizationImplem
        );
        await this.marketCreator.waitForDeployment();

        this.pegKeeperRegulator = (await (
            await ethers.getContractFactory("PegKeeperRegulator")
        ).deploy(this.tgUSD, tgUSDOracle, this.feeTreso, this.owner, this.owner)) as unknown as IPegKeeperRegulator;
        await this.pegKeeperRegulator.waitForDeployment();

        this.pegKeeperTgUSD_USDC = (await (
            await ethers.getContractFactory("PegKeeperV2")
        ).deploy(this.stableLp["tgUSD-USDC"], "20000", this.pegKeeperRegulator, this.owner)) as unknown as IPegKeeperV2;
        await this.pegKeeperTgUSD_USDC.waitForDeployment();

        await this.pegKeeperRegulator.connect(this.owner).add_peg_keepers([this.pegKeeperTgUSD_USDC]);

        await this.controlTower.connect(this.owner).toggleMarketCreator(this.marketCreator);
    }

    async setUpERC20() {
        this.coins["usdc"] = await ethers.getContractAt("IERC20", commonERC20.USDC);
        this.coins["crvUSD_USDC"] = await ethers.getContractAt("IERC20", curveLp.crvUSD_USDC);

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
