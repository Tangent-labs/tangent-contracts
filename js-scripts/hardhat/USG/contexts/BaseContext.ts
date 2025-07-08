import {ethers} from "hardhat";

import {commonERC20, curveLp} from "defi-resources";

import {MainSetup} from "../../Main.setup";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {AddressLike, MaxUint256, parseEther} from "ethers";
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
    BasicERC20Market,
    RewardAccumulator,
    VsTan,
    Tan,
    USG,
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
    USG!: USG;
    sUSG!: IYearnV3Vault;
    tan!: Tan;
    vsTan!: VsTan;
    rewardAccumulator!: RewardAccumulator;
    irCalculator!: IRCalculator;
    marketCreator!: MarketCreator;
    zappingProxy!: ZappingProxy;

    pegKeeperRegulator!: IPegKeeperRegulator;
    pegKeeperUSG_USDC!: IPegKeeperV2;
    pegKeeperUSG_wfrxUSD!: IPegKeeperV2;

    marketCvxCrvImplem!: ConvexCrvLPMarket;
    marketCvxFxnImplem!: ConvexFxnLPMarket;
    marketBasicER20Implem!: BasicERC20Market;

    coins: {[name: string]: IERC20Metadata} = {};

    async deployContracts1() {
        this.owner = this.users[0];
        this.feeTreso = this.users[4];

        this.controlTower = await (await ethers.getContractFactory("ControlTower")).deploy(this.owner, this.feeTreso);
        await this.controlTower.waitForDeployment();

        this.USG = await (await ethers.getContractFactory("USG")).deploy(this.owner, this.controlTower);
        await this.USG.waitForDeployment();

        this.zappingProxy = await (await ethers.getContractFactory("ZappingProxy")).deploy();
        await this.zappingProxy.waitForDeployment();

        await this.deploysUSG();

        this.tan = await (await ethers.getContractFactory("Tan")).deploy(this.owner);
        await this.tan.waitForDeployment();

        this.vsTan = await (await ethers.getContractFactory("VsTan")).deploy(this.owner, this.controlTower, this.tan, this.USG, this.sUSG, this.zappingProxy);
        await this.vsTan.waitForDeployment();
        await this.vsTan.addNewReward(this.USG);

        this.marketCvxCrvImplem = await (await ethers.getContractFactory("ConvexCrvLPMarket")).deploy();
        await this.marketCvxCrvImplem.waitForDeployment();

        this.marketCvxFxnImplem = await (await ethers.getContractFactory("ConvexFxnLPMarket")).deploy();
        await this.marketCvxFxnImplem.waitForDeployment();

        this.marketBasicER20Implem = await (await ethers.getContractFactory("BasicERC20Market")).deploy();
        await this.marketBasicER20Implem.waitForDeployment();
    }

    async deploysUSG() {
        const yearnVaultFactory = await ethers.getContractAt("IYearnVaultFactory", "0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F");
        const tx = await yearnVaultFactory.deploy_new_vault(this.USG, "Staked USG", "sUSG", this.owner, 7 * 86400);
        await tx.wait();
        const actualBlock = (await ethers.provider.getBlock("latest"))!.number;
        const createEvents = await yearnVaultFactory.queryFilter(yearnVaultFactory.filters.NewVault(), actualBlock - 1, actualBlock);

        this.sUSG = await ethers.getContractAt("IYearnV3Vault", "0x" + createEvents[0].topics[1].slice(26));

        // Set deposit limit
        await this.sUSG.add_role(this.owner, 256);
        // Set reward processor
        await this.sUSG.add_role(this.owner, 32);
        // Set max number as maximum to deposit
        await this.sUSG["set_deposit_limit(uint256)"](ethers.MaxUint256);
    }

    async deployContracts2(USGOracle: AddressLike, lpDeployContext: LpDeployContext) {
        this.irCalculator = await (await ethers.getContractFactory("IRCalculator")).deploy(this.owner, this.controlTower, USGOracle, this.USG);
        await this.irCalculator.waitForDeployment();
        await this.controlTower.toggleIRCalculator(this.irCalculator);

        this.rewardAccumulator = await (await ethers.getContractFactory("RewardAccumulator")).deploy(this.owner, this.controlTower, USGOracle);
        await this.rewardAccumulator.waitForDeployment();

        this.marketCreator = await (
            await ethers.getContractFactory("MarketCreator")
        ).deploy(
            this.owner,
            this.controlTower,
            this.USG,
            this.irCalculator,
            this.rewardAccumulator,
            this.zappingProxy,
            this.marketCvxCrvImplem,
            this.marketCvxFxnImplem,
            this.marketBasicER20Implem
        );
        await this.marketCreator.waitForDeployment();

        this.pegKeeperRegulator = (await (
            await ethers.getContractFactory("PegKeeperRegulator")
        ).deploy(this.USG, USGOracle, this.feeTreso, this.owner, this.owner)) as unknown as IPegKeeperRegulator;
        await this.pegKeeperRegulator.waitForDeployment();

        this.pegKeeperUSG_USDC = (await (
            await ethers.getContractFactory("PegKeeperV2")
        ).deploy(lpDeployContext.stableLp["USG-USDC"], "20000", this.pegKeeperRegulator, this.owner)) as unknown as IPegKeeperV2;
        await this.pegKeeperUSG_USDC.waitForDeployment();

        this.pegKeeperUSG_wfrxUSD = (await (
            await ethers.getContractFactory("PegKeeperV2")
        ).deploy(lpDeployContext.stableLp["USG-wfrxUSD"], "20000", this.pegKeeperRegulator, this.owner)) as unknown as IPegKeeperV2;
        await this.pegKeeperUSG_wfrxUSD.waitForDeployment();

        await this.pegKeeperRegulator.connect(this.owner).add_peg_keepers([this.pegKeeperUSG_USDC, this.pegKeeperUSG_wfrxUSD]);

        await this.controlTower.connect(this.owner).togglePegKeeper(this.pegKeeperUSG_USDC);
        await this.controlTower.connect(this.owner).togglePegKeeper(this.pegKeeperUSG_wfrxUSD);
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

        const USGToGivePerUser = 3_000_000;

        await this.giveTokens(this.users, [{address: await this.USG.getAddress(), decimals: 18, isVyper: false, slotBalance: 0, amount: USGToGivePerUser}]);

        await setStorageAt(await this.USG.getAddress(), 2, parseEther((USGToGivePerUser * this.users.length).toString()));
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

    oracles["USG"] = await oracleContext.USGOracle.getAddress();
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
            USG: await baseContext.USG.getAddress(),
            sUSG: await baseContext.sUSG.getAddress(),
            tan: await baseContext.tan.getAddress(),
            vsTan: await baseContext.vsTan.getAddress(),
        },
        implementations: {
            convexCrvMarket: await baseContext.marketCvxCrvImplem.getAddress(),
            convexFxnMarket: await baseContext.marketCvxFxnImplem.getAddress(),
            basicERC20Market: await baseContext.marketBasicER20Implem.getAddress(),
        },
        markets,
        oracles,
        lps,
        wStables,
        pegKeepers: {
            "USG-USDC": await baseContext.pegKeeperUSG_USDC.getAddress(),
            "USG-wfrxUSD": await baseContext.pegKeeperUSG_wfrxUSD.getAddress(),
        },
    };
}

export type Market = {
    marketAddress: string;
    collatName: string;
    collatAddress: string;
    marketType: string;
};
