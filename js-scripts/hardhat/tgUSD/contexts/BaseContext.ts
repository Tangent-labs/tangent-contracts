import {ethers} from "hardhat";

import {commonERC20, curveLp} from "defi-resources";

import {MainSetup} from "../../Main.setup";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {AddressLike, MaxUint256, parseEther, ZeroAddress} from "ethers";
import {
    ControlTower,
    ConvexCrvLPMarket,
    ConvexFxnLPMarket,
    IERC20Metadata,
    IPegKeeperRegulator,
    IPegKeeperV2,
    IRCalculator,
    IYearnV3Vault,
    LiquidatorProxy,
    MarketCreator,
    MarketNoSociabilization,
    RewardAccumulator,
    RsTan,
    Tan,
    TgUSD,
    Zapper,
} from "../../../../typechain-types";
import {LpDeployContext} from "./LPDeployContext";
import {setStorageAt} from "@nomicfoundation/hardhat-toolbox/network-helpers";

export class BaseContext extends MainSetup {
    owner!: HardhatEthersSigner;
    feeTreso!: HardhatEthersSigner;

    controlTower!: ControlTower;
    tgUSD!: TgUSD;
    sgUSD!: IYearnV3Vault;
    tan!: Tan;
    rsTan!: RsTan;
    zapper!: Zapper;
    rewardAccumulator!: RewardAccumulator;
    liquidatorProxy!: LiquidatorProxy;
    irCalculator!: IRCalculator;
    marketCreator!: MarketCreator;

    pegKeeperRegulator!: IPegKeeperRegulator;
    pegKeeperTgUSD_USDC!: IPegKeeperV2;
    pegKeeperTgUSD_frxUSD!: IPegKeeperV2;

    marketCvxCrvImplem!: ConvexCrvLPMarket;
    marketCvxFxnImplem!: ConvexFxnLPMarket;
    marketNoSociabilizationImplem!: MarketNoSociabilization;

    coins: {[name: string]: IERC20Metadata} = {};

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

        this.tan = await (await ethers.getContractFactory("Tan")).deploy();
        await this.tan.waitForDeployment();

        await this.tan.mint(this.users[0], parseEther("100000"));
        await this.tan.mint(this.users[1], parseEther("100000"));
        await this.tan.mint(this.users[2], parseEther("100000"));
        await this.tan.mint(this.users[3], parseEther("100000"));
        await this.tan.mint(this.users[4], parseEther("100000"));

        this.rsTan = await (await ethers.getContractFactory("RsTan")).deploy(this.controlTower, this.owner, this.tan);
        await this.rsTan.waitForDeployment();
        await this.rsTan.addNewReward(this.tgUSD);

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

    async deployContracts2(tgUSDOracle: AddressLike, lpDeployContext: LpDeployContext) {
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
        ).deploy(lpDeployContext.stableLp["tgUSD-USDC"], "20000", this.pegKeeperRegulator, this.owner)) as unknown as IPegKeeperV2;
        await this.pegKeeperTgUSD_USDC.waitForDeployment();

        this.pegKeeperTgUSD_frxUSD = (await (
            await ethers.getContractFactory("PegKeeperV2")
        ).deploy(lpDeployContext.stableLp["tgUSD-wfrxUSD"], "20000", this.pegKeeperRegulator, this.owner)) as unknown as IPegKeeperV2;
        await this.pegKeeperTgUSD_frxUSD.waitForDeployment();

        await this.pegKeeperRegulator.connect(this.owner).add_peg_keepers([this.pegKeeperTgUSD_USDC]);

        await this.controlTower.connect(this.owner).toggleMarketCreator(this.marketCreator);
    }

    async setUpERC20() {
        this.coins["USDC"] = await ethers.getContractAt("IERC20Metadata", commonERC20.USDC);

        this.coins["frxUSD"] = await ethers.getContractAt("IERC20Metadata", commonERC20.frxUSD);
        this.coins["sfrxUSD"] = await ethers.getContractAt("IERC20Metadata", commonERC20.sfrxUSD);

        this.coins["crvUSD"] = await ethers.getContractAt("IERC20Metadata", commonERC20.crvUSD);
        this.coins["scrvUSD"] = await ethers.getContractAt("IERC20Metadata", commonERC20.scrvUSD);

        this.coins["USDe"] = await ethers.getContractAt("IERC20Metadata", commonERC20.USDe);
        this.coins["sUSDe"] = await ethers.getContractAt("IERC20Metadata", commonERC20.sUSDe);

        this.coins["DOLA"] = await ethers.getContractAt("IERC20Metadata", commonERC20.DOLA);
        this.coins["sDOLA"] = await ethers.getContractAt("IERC20Metadata", commonERC20.sDOLA);

        this.coins["USR"] = await ethers.getContractAt("IERC20Metadata", commonERC20.USR);
        this.coins["wstUSR"] = await ethers.getContractAt("IERC20Metadata", commonERC20.wstUSR);

        this.coins["crvUSD_USDC"] = await ethers.getContractAt("IERC20Metadata", curveLp.crvUSD_USDC);

        const tgUSDToGivePerUser = 3_000_000;

        await this.giveTokens(this.users, [{address: await this.tgUSD.getAddress(), decimals: 18, isVyper: false, slotBalance: 5, amount: tgUSDToGivePerUser}]);

        await setStorageAt(await this.tgUSD.getAddress(), 7, parseEther((tgUSDToGivePerUser * this.users.length).toString()));
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
