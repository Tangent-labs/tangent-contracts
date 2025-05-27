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
    MarketCreator,
    MarketNoSociabilization,
    RewardAccumulator,
    RsTan,
    Tan,
    TgUSD,
    ZappingProxy,
} from "../../../../typechain-types";
import {LpDeployContext} from "./LPDeployContext";
import {setStorageAt} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import {ConvexCrvMarketKeys, ConvexFxnMarketKeys, MarketContext, PendlePTMarketsKeys} from "./MarketContext";
import {STATIC_CONFIG_CONVEX_CURVE, STATIC_CONFIG_CONVEX_FXN, STATIC_CONFIG_PT_PENDLE} from "../config/market";
import {OracleContext} from "./OracleContext";
import {WStablesContext} from "./WStableContext";

export class BaseContext extends MainSetup {
    owner!: HardhatEthersSigner;
    feeTreso!: HardhatEthersSigner;

    controlTower!: ControlTower;
    tgUSD!: TgUSD;
    sgUSD!: IYearnV3Vault;
    tan!: Tan;
    rsTan!: RsTan;
    rewardAccumulator!: RewardAccumulator;
    irCalculator!: IRCalculator;
    marketCreator!: MarketCreator;
    zappingProxy!: ZappingProxy;

    pegKeeperRegulator!: IPegKeeperRegulator;
    pegKeeperTgUSD_USDC!: IPegKeeperV2;
    pegKeeperTgUSD_wfrxUSD!: IPegKeeperV2;

    marketCvxCrvImplem!: ConvexCrvLPMarket;
    marketCvxFxnImplem!: ConvexFxnLPMarket;
    marketNoSociabilizationImplem!: MarketNoSociabilization;

    coins: {[name: string]: IERC20Metadata} = {};

    async deployContracts1() {
        this.owner = this.users[0];
        this.feeTreso = this.users[4];

        this.controlTower = await (await ethers.getContractFactory("ControlTower")).deploy(this.owner, this.feeTreso);
        await this.controlTower.waitForDeployment();

        this.tgUSD = await (await ethers.getContractFactory("TgUSD")).deploy(this.owner, this.controlTower);
        await this.tgUSD.waitForDeployment();

        this.zappingProxy = await (await ethers.getContractFactory("ZappingProxy")).deploy();
        await this.zappingProxy.waitForDeployment();

        await this.deploySgUSD();

        this.tan = await (await ethers.getContractFactory("Tan")).deploy(this.owner);
        await this.tan.waitForDeployment();

        this.rsTan = await (await ethers.getContractFactory("RsTan")).deploy(this.owner, this.controlTower, this.tan, this.tgUSD, this.sgUSD, this.zappingProxy);
        await this.rsTan.waitForDeployment();
        await this.rsTan.addNewReward(this.tgUSD);

        this.marketCvxCrvImplem = await (await ethers.getContractFactory("ConvexCrvLPMarket")).deploy();
        await this.marketCvxCrvImplem.waitForDeployment();

        this.marketCvxFxnImplem = await (await ethers.getContractFactory("ConvexFxnLPMarket")).deploy();
        await this.marketCvxFxnImplem.waitForDeployment();

        this.marketNoSociabilizationImplem = await (await ethers.getContractFactory("MarketNoSociabilization")).deploy();
        await this.marketNoSociabilizationImplem.waitForDeployment();
    }

    async deploySgUSD() {
        const yearnVaultFactory = await ethers.getContractAt("IYearnVaultFactory", "0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F");
        const tx = await yearnVaultFactory.deploy_new_vault(this.tgUSD, "Staked tgUSD", "sgUSD", this.owner, 7 * 86400);
        await tx.wait();
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
        this.irCalculator = await (await ethers.getContractFactory("IRCalculator")).deploy(this.owner, this.controlTower, tgUSDOracle, this.tgUSD);
        await this.irCalculator.waitForDeployment();
        await this.controlTower.toggleIRCalculator(this.irCalculator);

        this.rewardAccumulator = await (await ethers.getContractFactory("RewardAccumulator")).deploy(this.owner, this.controlTower, tgUSDOracle);
        await this.rewardAccumulator.waitForDeployment();

        this.marketCreator = await (
            await ethers.getContractFactory("MarketCreator")
        ).deploy(
            this.owner,
            this.controlTower,
            this.tgUSD,
            this.irCalculator,
            this.rewardAccumulator,
            this.zappingProxy,
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

        this.pegKeeperTgUSD_wfrxUSD = (await (
            await ethers.getContractFactory("PegKeeperV2")
        ).deploy(lpDeployContext.stableLp["tgUSD-wfrxUSD"], "20000", this.pegKeeperRegulator, this.owner)) as unknown as IPegKeeperV2;
        await this.pegKeeperTgUSD_wfrxUSD.waitForDeployment();

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

        await this.giveTokens(this.users, [{address: await this.tgUSD.getAddress(), decimals: 18, isVyper: false, slotBalance: 0, amount: tgUSDToGivePerUser}]);

        await setStorageAt(await this.tgUSD.getAddress(), 2, parseEther((tgUSDToGivePerUser * this.users.length).toString()));
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

export async function createJSONAddress(
    baseContext: BaseContext,
    marketContext: MarketContext,
    oracleContext: OracleContext,
    lpDeployContext: LpDeployContext,
    wStableContext: WStablesContext
) {
    const markets: Market[] = [];
    for (const key in marketContext.convexCrvMarkets) {
        const staticConfig = STATIC_CONFIG_CONVEX_CURVE[key as ConvexCrvMarketKeys];
        const market = await marketContext.convexCrvMarkets[key].getAddress();

        markets.push({
            marketAddress: market,
            collatName: staticConfig.collatName,
            collatAddress: staticConfig.collatToken,
            marketType: "Convex_CRV",
        });
    }
    for (const key in marketContext.convexFxnMarkets) {
        const market = await marketContext.convexFxnMarkets[key].getAddress();
        const staticConfig = STATIC_CONFIG_CONVEX_FXN[key as ConvexFxnMarketKeys];

        markets.push({
            marketAddress: market,
            collatName: staticConfig.collatName,
            collatAddress: staticConfig.collatToken,
            marketType: "Convex_FXN",
        });
    }

    for (const key in marketContext.pendlePTMarkets) {
        const market = await marketContext.pendlePTMarkets[key].getAddress();
        const staticConfig = STATIC_CONFIG_PT_PENDLE[key as PendlePTMarketsKeys];

        markets.push({
            marketAddress: market,
            collatName: staticConfig.collatName,
            collatAddress: staticConfig.collatToken,
            marketType: "Pendle_PT",
        });
    }

    let oracles: {[key: string]: string} = {};
    for (const prop in oracleContext.oracles) {
        const oracle = await oracleContext.oracles[prop].getAddress();
        oracles[prop] = oracle;
    }

    const lps: {[key: string]: string} = {};
    for (const prop in lpDeployContext.stableLp) {
        const lp = await lpDeployContext.stableLp[prop].getAddress();
        lps[prop] = lp;
    }

    const wStables: {[key: string]: string} = {};
    for (const prop in wStableContext.wStable) {
        const wStable = await wStableContext.wStable[prop].getAddress();
        wStables[prop] = wStable;
    }

    oracles["tgUSD"] = await oracleContext.tgUSDOracle.getAddress();
    return {
        utilities: {
            controlTower: await baseContext.controlTower.getAddress(),
            rewardAccumulator: await baseContext.rewardAccumulator.getAddress(),
            zappingProxy: await baseContext.zappingProxy.getAddress(),
            marketCreator: await baseContext.marketCreator.getAddress(),
            irCalculator: await baseContext.irCalculator.getAddress(),
            pegKeeperRegulator: await baseContext.pegKeeperRegulator.getAddress(),
        },
        tokens: {
            tgUSD: await baseContext.tgUSD.getAddress(),
            sgUSD: await baseContext.sgUSD.getAddress(),
            tan: await baseContext.tan.getAddress(),
            rsTan: await baseContext.rsTan.getAddress(),
        },
        implementations: {
            convexCrvMarket: await baseContext.marketCvxCrvImplem.getAddress(),
            convexFxnMarket: await baseContext.marketCvxFxnImplem.getAddress(),
            noSociabilizationMarket: await baseContext.marketNoSociabilizationImplem.getAddress(),
        },
        markets,
        oracles,
        lps,
        wStables,
        pegKeepers: {
            "tgUSD-USDC": await baseContext.pegKeeperTgUSD_USDC.getAddress(),
            "tgUSD-wfrxUSD": await baseContext.pegKeeperTgUSD_wfrxUSD.getAddress(),
        },
    };
}

export type Market = {
    marketAddress: string;
    collatName: string;
    collatAddress: string;
    marketType: string;
};
