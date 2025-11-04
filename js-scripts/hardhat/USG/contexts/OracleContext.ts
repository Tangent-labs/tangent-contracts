import { ethers } from "hardhat";
import { curveLp, CHAINLINK_PRICE_FEEDS, PendlePools, commonERC20 } from "@tangent/defi-resources";
import { IAggregatorStablePriceV3, IPriceOracle } from "../../../../typechain-types";
import { BaseContext } from "./BaseContext";
import { LpDeployContext } from "./LPDeployContext";
import { chainlinkOracleParams, oracleCoinFromCurveLPParams, oracleCryptoSwapParams, oracleDuoPoolStableParams, oracleERC4626Params, oraclePendlePTParams } from "./oracleParams";
import { ZeroAddress } from "ethers";

export class OracleContext {
    USGOracle!: IAggregatorStablePriceV3;
    oracles: { [key: string]: IPriceOracle } = {};

    async deployChainlinkWrappers() {
        const ChainlinkWrapperFactory = await ethers.getContractFactory("OracleChainlinkWrapper");

        for (let index = 0; index < chainlinkOracleParams.length; index++) {
            const item = chainlinkOracleParams[index];
            this.oracles[item.key] = await ChainlinkWrapperFactory.deploy(await ethers.getContractAt("IPriceOracle", CHAINLINK_PRICE_FEEDS[item.oracleName]), 10000000000, ZeroAddress);
        }
    }

    async deployOracleCoinFromCurveLP() {
        const OracleCoinFromCurveLPFactory = await ethers.getContractFactory("OracleCoinFromCurveLP");

        for (let index = 0; index < oracleCoinFromCurveLPParams.length; index++) {
            const item = oracleCoinFromCurveLPParams[index];
            this.oracles[item.key] = (await OracleCoinFromCurveLPFactory.deploy(curveLp[item.lp], this.oracles[item.coin0Oracle], item.isReversed)) as unknown as IPriceOracle;
        }
    }

    async deployOracleCoinERC4626() {
        const OracleERC4626Factory = await ethers.getContractFactory("OracleERC4626");

        for (let index = 0; index < oracleERC4626Params.length; index++) {
            const item = oracleERC4626Params[index];
            this.oracles[item.erc4626] = (await OracleERC4626Factory.deploy(commonERC20[item.erc4626], this.oracles[item.underlyingOracle])) as unknown as IPriceOracle;
        }
    }

    async deployOracleDuoPoolStable() {
        const OracleDuoPoolStableFactory = await ethers.getContractFactory("OracleDuoPoolStable");

        for (let index = 0; index < oracleDuoPoolStableParams.length; index++) {
            const item = oracleDuoPoolStableParams[index];
            const oracle0 = this.oracles[item.coin0Oracle];
            this.oracles[item.key] = (await OracleDuoPoolStableFactory.deploy(curveLp[item.lp], oracle0, this.oracles[item.coin1Oracle])) as unknown as IPriceOracle;
        }
    }

    async deployOracleCryptoSwap() {
        const OracleCryptoSwapFactory = await ethers.getContractFactory("OracleCryptoSwap");

        for (let index = 0; index < oracleCryptoSwapParams.length; index++) {
            const item = oracleCryptoSwapParams[index];
            this.oracles[item.key] = (await OracleCryptoSwapFactory.deploy(curveLp[item.lp], this.oracles[item.coin0Oracle])) as unknown as IPriceOracle;
        }
    }

    async deployOraclePendlePT() {
        const OraclePendlePTFactory = await ethers.getContractFactory("OraclePendlePT");
        for (let index = 0; index < oraclePendlePTParams.length; index++) {
            const item = oraclePendlePTParams[index];
            this.oracles[item.key] = (await OraclePendlePTFactory.deploy(PendlePools[item.key].MARKET, this.oracles[item.underlyingOracle], 900, 18)) as unknown as IPriceOracle;
        }
    }

    async deployAndSetupOracles(baseContext: BaseContext, lpDeployContext: LpDeployContext) {
        await this.deployChainlinkWrappers();
        await this.deployOracleCoinFromCurveLP();
        await this.deployOracleDuoPoolStable();
        await this.deployOracleCryptoSwap();
        await this.deployOracleCoinERC4626();
        await this.deployOraclePendlePT();

        this.USGOracle = (await (
            await ethers.getContractFactory("AggregatorStablePriceV3")
        ).deploy(baseContext.USG, "1000000000000000", baseContext.owner)) as unknown as IAggregatorStablePriceV3;
        await this.USGOracle.waitForDeployment();

        await this.USGOracle.connect(baseContext.owner).add_price_pair(lpDeployContext.stableLp["USG-USDC"]);
        await this.USGOracle.connect(baseContext.owner).add_price_pair(lpDeployContext.stableLp["USG-wcrvUSD"]);
    }
}
