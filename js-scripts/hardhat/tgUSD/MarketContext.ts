import {ethers} from "hardhat";
import {commonERC20, curveLp} from "convergence-defi-tools";
import {MaxUint256, parseEther} from "ethers";
import {ConvexCrvLPMarket, ConvexFxnLPMarket, ICurveStableSwapNG} from "../../../typechain-types";
import {BaseContext} from "./BaseContext";
import {OracleContext} from "./OracleContext";
import {STATIC_CONFIG_CONVEX_CURVE, STATIC_CONFIG_CONVEX_FXN} from "./config/market";

export type ConvexCrvMarketKeys = keyof typeof STATIC_CONFIG_CONVEX_CURVE;
export type ConvexFxnMarketKeys = keyof typeof STATIC_CONFIG_CONVEX_FXN;
export type Markets = ConvexCrvLPMarket | ConvexFxnLPMarket;

export class MarketContext {
    markets: {[key: string]: ConvexCrvLPMarket | ConvexFxnLPMarket} = {};

    async deployConvexCrvMarkets(key: ConvexCrvMarketKeys, baseContext: BaseContext, oracleContext: OracleContext) {
        const ConvexCrvLPMarketFactory = await ethers.getContractFactory("ConvexCrvLPMarket");
        const staticConfig = STATIC_CONFIG_CONVEX_CURVE[key];
        const market = await ConvexCrvLPMarketFactory.deploy(
            baseContext.owner,
            {
                collatOracle: oracleContext.crvUSD_USDC,
                collatToken: staticConfig.collatToken,
                controlTower: baseContext.controlTower,
                irCalculator: baseContext.irCalculator,
                liquidationThreshold: staticConfig.liquidationThreshold,
                maxLTV: staticConfig.maxLTV,
                maxMarketDebt: staticConfig.maxMarketDebt,
                minimumLoan: staticConfig.minimumLoan,
                tgUSD: baseContext.tgUSD,
            },
            baseContext.rewardAccumulator,
            staticConfig.rewards,
            staticConfig.cvxRewardToken,
            staticConfig.pid
        );
        await market.waitForDeployment();

        await this.setupPostMarketDeploy(key, market, baseContext);
    }

    async deployConvexFxnMarkets(key: ConvexFxnMarketKeys, baseContext: BaseContext, oracleContext: OracleContext) {
        const ConvexFxnLPMarketFactory = await ethers.getContractFactory("ConvexFxnLPMarket");
        const staticConfig = STATIC_CONFIG_CONVEX_FXN[key];
        const market = await ConvexFxnLPMarketFactory.deploy(
            baseContext.owner,
            {
                collatOracle: oracleContext.crvUSD_USDC,
                collatToken: staticConfig.collatToken,
                controlTower: baseContext.controlTower,
                irCalculator: baseContext.irCalculator,
                liquidationThreshold: staticConfig.liquidationThreshold,
                maxLTV: staticConfig.maxLTV,
                maxMarketDebt: staticConfig.maxMarketDebt,
                minimumLoan: staticConfig.minimumLoan,
                tgUSD: baseContext.tgUSD,
            },
            baseContext.rewardAccumulator,
            staticConfig.rewards,
            staticConfig.pid
        );
        await market.waitForDeployment();

        await this.setupPostMarketDeploy(key, market, baseContext);
    }

    async setupPostMarketDeploy(key: string, market: Markets, baseContext: BaseContext) {
        for (let i = 0; i < baseContext.users.length; i++) {
            await (await ethers.getContractAt("IERC20", curveLp.CRVUSD_USDC)).connect(baseContext.users[i]).approve(market, MaxUint256);
        }
        await baseContext.controlTower.connect(baseContext.owner).toggleMarkets([market]);
        await baseContext.irCalculator
            .connect(baseContext.owner)
            .setUpMarketRewards(
                market,
                {r0: parseEther("5"), sigma: 2750000000000000n},
                {stepAmount: 5, cutAtOneDollar: 50_000, fullCutPrice: parseEther("0.995")}
            );
        this.markets[key] = market;
    }
}
