import {ethers} from "hardhat";
import {commonERC20, curveLp} from "convergence-defi-tools";
import {MaxUint256, parseEther} from "ethers";
import {ConvexCrvLPMarket} from "../../../typechain-types";
import {BaseContext} from "./BaseContext";
import {OracleContext} from "./OracleContext";

export class MarketContext {
    Cvx_crvUSD_USDC!: ConvexCrvLPMarket;

    async deployMarkets(baseContext: BaseContext, oracleContext: OracleContext) {
        const ConvexCrvLPMarketFactory = await ethers.getContractFactory("ConvexCrvLPMarket");
        const crvUSD_USDC_Cvx_Market = await ConvexCrvLPMarketFactory.deploy(
            baseContext.owner,
            {
                collatOracle: oracleContext.crvUSD_USDC,
                collatToken: curveLp.CRVUSD_USDC,
                controlTower: baseContext.controlTower,
                irCalculator: baseContext.irCalculator,
                liquidationThreshold: 93_000,
                maxLTV: 85_000,
                maxMarketDebt: parseEther("1000000"),
                minimumLoan: parseEther("3000"),
                tgUSD: baseContext.tgUSD,
            },
            baseContext.rewardAccumulator,
            [commonERC20.CRV, commonERC20.CVX],
            "0x44D8FaB7CD8b7877D5F79974c2F501aF6E65AbBA",
            182
        );
        await crvUSD_USDC_Cvx_Market.waitForDeployment();

        for (let i = 0; i < baseContext.users.length; i++) {
            await (await ethers.getContractAt("IERC20", curveLp.CRVUSD_USDC)).connect(baseContext.users[i]).approve(crvUSD_USDC_Cvx_Market, MaxUint256);
        }
        await baseContext.controlTower.connect(baseContext.owner).toggleMarkets([crvUSD_USDC_Cvx_Market]);
        await baseContext.irCalculator
            .connect(baseContext.owner)
            .setUpMarketRewards(
                crvUSD_USDC_Cvx_Market,
                {r0: parseEther("5"), sigma: 2750000000000000n},
                {stepAmount: 5, cutAtOneDollar: 50_000, fullCutPrice: parseEther("0.995")}
            );
        this.Cvx_crvUSD_USDC = crvUSD_USDC_Cvx_Market;
    }
}
