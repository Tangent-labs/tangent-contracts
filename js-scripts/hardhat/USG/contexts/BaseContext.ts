import { ethers } from "hardhat";

import { COMMON_ERC20S, CURVE_LPS } from "@tangent/defi-resources";

import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { impersonateAccount, setStorageAt, stopImpersonatingAccount } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { AddressLike, MaxUint256, parseEther } from "ethers";
import { PROD_ADDRESSES } from "../../../../ignition/prod_addresses";
import {
    BasicERC20Market,
    ControlTower,
    ConvexCrvLPMarket,
    ConvexFxnLPMarket,
    CurveGaugeMarket,
    IERC20Metadata,
    IPegKeeperRegulator,
    IPegKeeperV2,
    IRCalculator,
    IYearnV3Vault,
    MarketCreator,
    MarketViewer,
    PendlePTRouter,
    RewardAccumulator,
    StakeDaoVaultV2Market,
    TAN,
    USG,
    VsTAN,
    ZappingProxy
} from "../../../../typechain-types";
import { MainSetup } from "../../Main.setup";
import { STATIC_CONFIG_BASIC_ERC20s, STATIC_CONFIG_CONVEX_FXN, STATIC_CONFIG_CURVE_GAUGE, USGMarketType } from "../config/market";
import { STATIC_CONFIG_CONVEX_CURVE } from "../config/markets/convex_crv";
import { STATIC_CONFIG_STAKEDAO_VAULT_V2 } from "../config/markets/stakeDao";
import { LpDeployContext } from "./LPDeployContext";
import { BasicERC20MarketKeys, ConvexCrvMarketKeys, ConvexFxnMarketKeys, CurveGaugeMarketsKeys, MarketContext, StakeDaoVaultV2MarketsKeys } from "./MarketContext";
import { OracleContext } from "./OracleContext";
import { WStablesContext } from "./WStableContext";

export class BaseContext extends MainSetup {
    owner!: HardhatEthersSigner;
    feeTreso!: HardhatEthersSigner;
    pauser!: HardhatEthersSigner;

    controlTower!: ControlTower;
    USG!: USG;
    sUSG!: IYearnV3Vault;
    TAN!: TAN;
    sTAN!: IYearnV3Vault;
    vsTAN!: VsTAN;
    rewardAccumulator!: RewardAccumulator;
    irCalculator!: IRCalculator;

    marketCreator!: MarketCreator;
    marketViewer!: MarketViewer;

    zappingProxy!: ZappingProxy;
    pendlePTRouter!: PendlePTRouter;

    pegKeeperRegulator!: IPegKeeperRegulator;
    pegKeeperUSG_USDC!: IPegKeeperV2;
    pegKeeperUSG_frxUSD!: IPegKeeperV2;

    marketCvxCrvImplem!: ConvexCrvLPMarket;
    marketCvxFxnImplem!: ConvexFxnLPMarket;
    marketBasicER20Implem!: BasicERC20Market;
    marketCurveGaugeImplem!: CurveGaugeMarket;
    marketStakeDaoVaultV2Implem!: StakeDaoVaultV2Market;

    coins: { [name: string]: IERC20Metadata } = {};

    async fetchMainnetContracts() {

        this.owner = await ethers.getSigner(PROD_ADDRESSES.DAO)
        this.feeTreso = await ethers.getSigner(PROD_ADDRESSES.FEE_TRESO)

        // MAIN
        this.controlTower = await ethers.getContractAt("ControlTower", PROD_ADDRESSES.CONTROL_TOWER)
        this.USG = await ethers.getContractAt("USG", PROD_ADDRESSES.USG)
        this.sUSG = await ethers.getContractAt("IYearnV3Vault", PROD_ADDRESSES.sUSG)


        // Market implementations
        this.marketCvxCrvImplem = await ethers.getContractAt("ConvexCrvLPMarket", PROD_ADDRESSES.MARKETS_IMPLEMENTATION.CONVEX_CRV_LP_MARKET)
        this.marketCvxFxnImplem = await ethers.getContractAt("ConvexFxnLPMarket", PROD_ADDRESSES.MARKETS_IMPLEMENTATION.CONVEX_FXN_LP_MARKET)
        this.marketCurveGaugeImplem = await ethers.getContractAt("CurveGaugeMarket", PROD_ADDRESSES.MARKETS_IMPLEMENTATION.CURVE_GAUGE_MARKET)
        this.marketStakeDaoVaultV2Implem = await ethers.getContractAt("StakeDaoVaultV2Market", PROD_ADDRESSES.MARKETS_IMPLEMENTATION.STAKEDAO_VAULT_MARKET)
        this.marketBasicER20Implem = await ethers.getContractAt("BasicERC20Market", PROD_ADDRESSES.MARKETS_IMPLEMENTATION.BASIC_ERC20_MARKET)

        // Markets utils
        this.irCalculator = await ethers.getContractAt("IRCalculator", PROD_ADDRESSES.IR_CALCULATOR)
        this.rewardAccumulator = await ethers.getContractAt("RewardAccumulator", PROD_ADDRESSES.REWARDS_ACCUMULATOR)
        this.marketCreator = await ethers.getContractAt("MarketCreator", PROD_ADDRESSES.MARKET_CREATOR)
        this.marketViewer = await ethers.getContractAt("MarketViewer", PROD_ADDRESSES.MARKET_VIEWER)

        // Keepers
        this.pegKeeperRegulator = await ethers.getContractAt("PegKeeperRegulator", PROD_ADDRESSES.PEG_KEEPER_REGULATOR)
        this.pegKeeperUSG_USDC = await ethers.getContractAt("PegKeeperV2", PROD_ADDRESSES.KEEPER_USDC)
        this.pegKeeperUSG_frxUSD = await ethers.getContractAt("PegKeeperV2", PROD_ADDRESSES.KEEPER_frxUSD)

        // Routing
        this.pendlePTRouter = await ethers.getContractAt("PendlePTRouter", PROD_ADDRESSES.PENDLE_PT_ROUTER)
        this.zappingProxy = await ethers.getContractAt("ZappingProxy", PROD_ADDRESSES.ZAPPING_PROXY)

    }

    async deployContracts1(ownerIndex: number, pauserIndex: number, feeTresoIndex: number) {
        this.owner = this.users[ownerIndex];
        this.pauser = this.users[pauserIndex];
        this.feeTreso = this.users[feeTresoIndex];


        this.controlTower = await (await ethers.getContractFactory("ControlTower")).deploy(this.owner, this.feeTreso);
        await this.controlTower.waitForDeployment();

        this.marketViewer = await (await ethers.getContractFactory("MarketViewer")).deploy();
        await this.marketViewer.waitForDeployment();

        this.USG = await (await ethers.getContractFactory("USG")).deploy(this.owner, this.controlTower);
        await this.USG.waitForDeployment();


        this.zappingProxy = await (await ethers.getContractFactory("ZappingProxy")).deploy(this.controlTower);
        await this.zappingProxy.waitForDeployment();
        await this.deploy_sUSG();

        this.TAN = await (await ethers.getContractFactory("TAN")).deploy(this.owner);
        await this.TAN.waitForDeployment();

        await this.deploy_sTAN();

        this.vsTAN = await (await ethers.getContractFactory("VsTAN")).deploy(this.owner, this.controlTower, this.TAN, this.USG, this.sUSG, this.zappingProxy, ethers.parseEther("1000"));
        await this.vsTAN.waitForDeployment();
        await this.vsTAN.addNewReward(this.USG);

        this.marketCvxCrvImplem = await (await ethers.getContractFactory("ConvexCrvLPMarket")).deploy();
        await this.marketCvxCrvImplem.waitForDeployment();

        this.marketCvxFxnImplem = await (await ethers.getContractFactory("ConvexFxnLPMarket")).deploy();
        await this.marketCvxFxnImplem.waitForDeployment();

        this.marketBasicER20Implem = await (await ethers.getContractFactory("BasicERC20Market")).deploy();
        await this.marketBasicER20Implem.waitForDeployment();

        this.marketStakeDaoVaultV2Implem = await (await ethers.getContractFactory("StakeDaoVaultV2Market")).deploy();
        await this.marketStakeDaoVaultV2Implem.waitForDeployment();

        this.marketCurveGaugeImplem = await (await ethers.getContractFactory("CurveGaugeMarket")).deploy();
        await this.marketCurveGaugeImplem.waitForDeployment();

    }

    async deploy_sUSG() {
        const yearnVaultFactory = await ethers.getContractAt("IYearnVaultFactory", "0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F");
        const tx = await yearnVaultFactory.deploy_new_vault(this.USG, "Staked USG", "sUSG", this.owner, 7 * 86400);
        await tx.wait();
        const actualBlock = (await ethers.provider.getBlock("latest"))!.number;
        const createEvents = await yearnVaultFactory.queryFilter(yearnVaultFactory.filters.NewVault(), actualBlock - 2, actualBlock);

        this.sUSG = await ethers.getContractAt("IYearnV3Vault", "0x" + createEvents[0].topics[1].slice(26));

        // Set deposit limit manager
        await this.sUSG.add_role(this.owner, 256);
        // Set reward processor
        await this.sUSG.add_role(this.owner, 32);
        // Set max number as maximum to deposit
        await this.sUSG["set_deposit_limit(uint256)"](ethers.MaxUint256);
    }

    async deploy_sTAN() {
        const yearnVaultFactory = await ethers.getContractAt("IYearnVaultFactory", "0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F");
        const tx = await yearnVaultFactory.deploy_new_vault(this.TAN, "Staked TAN", "sTAN", this.owner, 7 * 86400);
        await tx.wait();
        const actualBlock = (await ethers.provider.getBlock("latest"))!.number;
        const createEvents = await yearnVaultFactory.queryFilter(yearnVaultFactory.filters.NewVault(), actualBlock - 1, actualBlock);

        this.sTAN = await ethers.getContractAt("IYearnV3Vault", "0x" + createEvents[0].topics[1].slice(26));

        // Set deposit limit
        await this.sTAN.add_role(this.owner, 256);
        // Set reward processor
        await this.sTAN.add_role(this.owner, 32);
        // Set max number as maximum to deposit
        await this.sTAN["set_deposit_limit(uint256)"](ethers.MaxUint256);
    }

    async deployContracts2(USGOracle: AddressLike, lpDeployContext: LpDeployContext) {
        this.irCalculator = await (await ethers.getContractFactory("IRCalculator")).deploy(this.owner, this.controlTower, USGOracle, this.USG);
        await this.irCalculator.waitForDeployment();
        await this.USG.setIsIRProducer(this.irCalculator, true);

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
            this.marketCurveGaugeImplem,
            this.marketStakeDaoVaultV2Implem,
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

        this.pegKeeperUSG_frxUSD = (await (
            await ethers.getContractFactory("PegKeeperV2")
        ).deploy(lpDeployContext.stableLp["USG-frxUSD"], "20000", this.pegKeeperRegulator, this.owner)) as unknown as IPegKeeperV2;
        await this.pegKeeperUSG_frxUSD.waitForDeployment();

        await this.pegKeeperRegulator.connect(this.owner).add_peg_keepers([this.pegKeeperUSG_USDC, this.pegKeeperUSG_frxUSD]);

        await this.USG.connect(this.owner).setIsPegKeeper(this.pegKeeperUSG_USDC, true);
        await this.USG.connect(this.owner).setIsPegKeeper(this.pegKeeperUSG_frxUSD, true);

        await this.controlTower.connect(this.owner).setIsMarketCreator(this.marketCreator, true);

        await this.USG.mintPegKeeper(this.pegKeeperUSG_USDC, ethers.parseEther("10000000"))
        await this.USG.mintPegKeeper(this.pegKeeperUSG_frxUSD, ethers.parseEther("1000000"))

        this.pendlePTRouter = await (await ethers.getContractFactory("PendlePTRouter")).deploy();
    }

    async setUpERC20() {
        this.coins["USG"] = await ethers.getContractAt("IERC20Metadata", PROD_ADDRESSES.USG);

        this.coins["USDC"] = await ethers.getContractAt("IERC20Metadata", COMMON_ERC20S.USDC);

        this.coins["frxUSD"] = await ethers.getContractAt("IERC20Metadata", COMMON_ERC20S.frxUSD);
        this.coins["sfrxUSD"] = await ethers.getContractAt("IERC20Metadata", COMMON_ERC20S.sfrxUSD);

        this.coins["crvUSD"] = await ethers.getContractAt("IERC20Metadata", COMMON_ERC20S.crvUSD);
        this.coins["scrvUSD"] = await ethers.getContractAt("IERC20Metadata", COMMON_ERC20S.scrvUSD);

        this.coins["USDe"] = await ethers.getContractAt("IERC20Metadata", COMMON_ERC20S.USDe);
        this.coins["sUSDe"] = await ethers.getContractAt("IERC20Metadata", COMMON_ERC20S.sUSDe);

        this.coins["DOLA"] = await ethers.getContractAt("IERC20Metadata", COMMON_ERC20S.DOLA);
        this.coins["sDOLA"] = await ethers.getContractAt("IERC20Metadata", COMMON_ERC20S.sDOLA);

        this.coins["USR"] = await ethers.getContractAt("IERC20Metadata", COMMON_ERC20S.USR);
        this.coins["wstUSR"] = await ethers.getContractAt("IERC20Metadata", COMMON_ERC20S.wstUSR);

        this.coins["crvUSD_USDC"] = await ethers.getContractAt("IERC20Metadata", CURVE_LPS.crvUSD_USDC);

        const USGToGivePerUser = 1_000_000;

        const usgTotalSupply = await this.coins["USG"].totalSupply()

        await this.giveTokens(this.users, [{ address: await this.USG.getAddress(), decimals: 18, isVyper: false, slotBalance: 0, amount: USGToGivePerUser }]);
        await setStorageAt(await this.USG.getAddress(), 2, usgTotalSupply + parseEther((USGToGivePerUser * this.users.length).toString()));

    }

    async approveCurveLP(lp: string) {
        const curveLP = await ethers.getContractAt("ICurveStableSwapNG", lp);
        const coin0 = await ethers.getContractAt("IERC20", await curveLP.coins(0));
        const coin1 = await ethers.getContractAt("IERC20", await curveLP.coins(1));

        for (let i = 0; i < 4; i++) {
            const user = this.users[i];
            if (user) {
                await impersonateAccount(await user.getAddress())
                await coin0.connect(user).approve(lp, MaxUint256);
                await coin1.connect(user).approve(lp, MaxUint256);
                await stopImpersonatingAccount(await user.getAddress())

            }
        }
    }
}
type MarketResult = {
    marketAddress: string
    marketName: string
    collatAddress: string
    marketType: USGMarketType
    collatDecimals?: number,
    logoURI?: string
}
export async function createJSONAddress(
    baseContext: BaseContext,
    marketContext: MarketContext,
    oracleContext: OracleContext,
    lpDeployContext: LpDeployContext,
    wStableContext: WStablesContext
) {
    const markets: MarketResult[] = [];
    for (const key in marketContext.convexCrvMarkets) {
        const staticConfig = STATIC_CONFIG_CONVEX_CURVE[key as ConvexCrvMarketKeys];
        const market = await marketContext.convexCrvMarkets[key].getAddress();

        markets.push({
            marketAddress: market,
            marketName: staticConfig.collatName,
            collatAddress: staticConfig.collatToken,
            marketType: "Convex_CRV"
        });
    }

    for (const key in marketContext.convexFxnMarkets) {
        const staticConfig = STATIC_CONFIG_CONVEX_FXN[key as ConvexFxnMarketKeys];
        const market = await marketContext.convexFxnMarkets[key].getAddress();

        markets.push({
            marketAddress: market,
            marketName: staticConfig.collatName,
            collatAddress: staticConfig.collatToken,
            marketType: "Convex_FXN",
        });
    }

    for (const key in marketContext.curveGaugeMarkets) {
        const market = await marketContext.curveGaugeMarkets[key].getAddress();
        const staticConfig = STATIC_CONFIG_CURVE_GAUGE[key as CurveGaugeMarketsKeys];

        markets.push({
            marketAddress: market,
            marketName: staticConfig.collatName,
            collatAddress: staticConfig.collatToken,
            marketType: "CRV_Gauge"
        });
    }

    for (const key in marketContext.stakeDaoVaultMarkets) {
        const market = await marketContext.stakeDaoVaultMarkets[key].getAddress();
        const staticConfig = STATIC_CONFIG_STAKEDAO_VAULT_V2[key as StakeDaoVaultV2MarketsKeys];

        markets.push({
            marketAddress: market,
            marketName: staticConfig.collatName,
            collatAddress: staticConfig.collatToken,
            marketType: "STAKEDAO_CRV_Vault",
        });
    }

    for (const key in marketContext.basicERC20Markets) {
        const market = await marketContext.basicERC20Markets[key].getAddress();
        const staticConfig = STATIC_CONFIG_BASIC_ERC20s[key as BasicERC20MarketKeys];

        markets.push({
            marketAddress: market,
            marketName: staticConfig.collatName,
            collatAddress: staticConfig.collatToken,
            marketType: "Pendle_PT",
            collatDecimals: staticConfig.collatDecimals ?? 18,
            logoURI: staticConfig.logo
        });
    }

    let oracles: { [oracleType: string]: { [key: string]: string } } = {};

    const chainlink: { [key: string]: string } = {};
    for (const prop in oracleContext.oraclesChainlink) {
        const oracle = await oracleContext.oraclesChainlink[prop].getAddress();
        chainlink[prop] = oracle;
    }
    oracles.chainlink = chainlink

    const erc4626s: { [key: string]: string } = {};
    for (const prop in oracleContext.oracles4626) {
        const oracle = await oracleContext.oracles4626[prop].getAddress();
        erc4626s[prop] = oracle;
    }
    oracles.erc4626s = erc4626s

    const coinFromCurveLp: { [key: string]: string } = {};
    for (const prop in oracleContext.oraclesCoinFromCurveLP) {
        const oracle = await oracleContext.oraclesCoinFromCurveLP[prop].getAddress();
        coinFromCurveLp[prop] = oracle;
    }
    oracles.coinFromCurveLp = coinFromCurveLp

    const duoPoolStable: { [key: string]: string } = {};
    for (const prop in oracleContext.oraclesDuoPoolStable) {
        const oracle = await oracleContext.oraclesDuoPoolStable[prop].getAddress();
        duoPoolStable[prop] = oracle;
    }
    oracles.duoPoolStable = duoPoolStable


    const pendlePT: { [key: string]: string } = {};
    for (const prop in oracleContext.oraclesPendlePT) {
        const oracle = await oracleContext.oraclesPendlePT[prop].getAddress();
        pendlePT[prop] = oracle;
    }
    oracles.pendlePT = pendlePT


    const lps: { [key: string]: string } = {};
    for (const prop in lpDeployContext.stableLp) {
        const lp = await lpDeployContext.stableLp[prop].getAddress();
        lps[prop] = lp;
    }

    lps["TAN-WETH"] = await lpDeployContext.tanLP?.getAddress()!;

    const wStables: { [key: string]: string } = {};
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
            pendlePTRouter: await baseContext.pendlePTRouter.getAddress(),
            marketViewer: await baseContext.marketViewer.getAddress()
        },
        tokens: {
            USG: await baseContext.USG.getAddress(),
            sUSG: await baseContext.sUSG.getAddress(),
            TAN: await baseContext?.TAN?.getAddress(),
            sTAN: await baseContext?.sTAN?.getAddress(),
            vsTAN: await baseContext?.vsTAN?.getAddress(),
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
            "USG-frxUSD": await baseContext.pegKeeperUSG_frxUSD.getAddress(),
        },
    };
}
