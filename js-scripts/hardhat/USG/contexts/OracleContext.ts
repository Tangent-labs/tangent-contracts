import { ethers } from "hardhat";
import { CHAINLINK_PRICE_FEEDS, PENDLE_POOLS, COMMON_ERC20S, CURVE_LPS } from "@tangent/defi-resources";
import { IAggregatorStablePriceV3, IPriceOracle } from "../../../../typechain-types";
import { BaseContext } from "./BaseContext";
import { LpDeployContext } from "./LPDeployContext";
import { chainlinkOracleParams, oracleCoinFromCurveLPParams, oracleCryptoSwapParams, oracleDuoPoolStableParams, oracleERC4626Params, oraclePendlePTParams } from "./oracleParams";
import { ZeroAddress } from "ethers";

export class OracleContext {
    USGOracle!: IAggregatorStablePriceV3;
    oracles: { [key: string]: IPriceOracle } = {};

    async deployAndSetupOracles(baseContext: BaseContext, lpDeployContext: LpDeployContext) {
        await this.deployChainlinkWrappers();
        await this.deployOracleCoinFromCurveLP();
        await this.deployOracleDuoPoolStable();

        // await this.deployOracleCryptoSwap();
        await this.deployOracleCoinERC4626();

        await this.deployOraclePendlePT();

        this.USGOracle = (await (
            await ethers.getContractFactory("AggregatorStablePriceV3")
        ).deploy(baseContext.USG, "1000000000000000", baseContext.owner)) as unknown as IAggregatorStablePriceV3;
        await this.USGOracle.waitForDeployment();

        await this.USGOracle.connect(baseContext.owner).add_price_pair(lpDeployContext.stableLp["USG-USDC"]);
        await this.USGOracle.connect(baseContext.owner).add_price_pair(lpDeployContext.stableLp["USG-frxUSD"]);
    }

    async deployChainlinkWrappers() {
        const ChainlinkWrapperFactory = await ethers.getContractFactory("OracleChainlinkWrapper");

        for (let index = 0; index < chainlinkOracleParams.length; index++) {
            const item = chainlinkOracleParams[index];
            this.oracles[item.key] = await ChainlinkWrapperFactory.deploy(
                await ethers.getContractAt("IPriceOracle", CHAINLINK_PRICE_FEEDS[item.oracleName]),
                10000000000,
                ZeroAddress,
                item.oracleName
            );
        }
    }

    async deployOracleCoinFromCurveLP() {
        const OracleCoinFromCurveLPFactory = await ethers.getContractFactory("OracleCoinFromCurveLP");

        for (let index = 0; index < oracleCoinFromCurveLPParams.length; index++) {
            const item = oracleCoinFromCurveLPParams[index];
            const curveLP = CURVE_LPS[item.lp];
            const coin0Oracle = this.oracles[item.coin0Oracle];

            if (!curveLP) {
                throw Error(`ERC4626 ${item.lp} not configured in defi-resources in CURVE_LPS for ${item.oracleName}`);
            }

            if (!coin0Oracle) {
                throw Error(`Oracle0 ${item.coin0Oracle} not deployed for ${item.oracleName}`);
            }
            this.oracles[item.key] = (await OracleCoinFromCurveLPFactory.deploy(curveLP, coin0Oracle, item.isReversed, item.key)) as unknown as IPriceOracle;
        }
    }

    async deployOracleCoinERC4626() {
        const OracleERC4626Factory = await ethers.getContractFactory("OracleERC4626");

        for (let index = 0; index < oracleERC4626Params.length; index++) {
            const item = oracleERC4626Params[index];
            const erc4626Address = COMMON_ERC20S[item.erc4626];
            const underlyingOracle = this.oracles[item.underlyingOracle];

            if (!erc4626Address) {
                throw Error(`ERC4626 ${item.erc4626} not configured in defi-resources in COMMON_ERC20S.ts for  ${item.oracleName}`);
            }
            if (!underlyingOracle) {
                throw Error(`${item.underlyingOracle} not deployed for ${item.oracleName}`);
            }
            this.oracles[item.erc4626] = (await OracleERC4626Factory.deploy(erc4626Address, underlyingOracle, item.oracleName)) as unknown as IPriceOracle;
        }
    }

    async deployOracleDuoPoolStable() {
        const OracleDuoPoolStableFactory = await ethers.getContractFactory("OracleDuoPoolStable");

        for (let index = 0; index < oracleDuoPoolStableParams.length; index++) {
            const item = oracleDuoPoolStableParams[index];
            const lpAddress = CURVE_LPS[item.lp];
            const oracle0 = this.oracles[item.coin0Oracle];
            const oracle1 = this.oracles[item.coin1Oracle];

            if (!lpAddress) {
                throw Error(`LP ${item.lp} not configured in defi-resources in CURVE_LPS for  ${item.oracleName}`);
            }
            if (!oracle0) {
                throw Error(`${item.coin0Oracle} (Oracle 0) not configured for ${item.oracleName}`);
            }
            if (!oracle1) {
                throw Error(`${item.coin1Oracle} (Oracle 1) not configured for ${item.oracleName}`);
            }
            this.oracles[item.key] = (await OracleDuoPoolStableFactory.deploy(lpAddress, oracle0, oracle1, item.oracleName)) as unknown as IPriceOracle;
        }
    }

    // async deployOracleCryptoSwap() {
    //     const OracleCryptoSwapFactory = await ethers.getContractFactory("OracleCryptoSwap");

    //     for (let index = 0; index < oracleCryptoSwapParams.length; index++) {
    //         const item = oracleCryptoSwapParams[index];
    //         this.oracles[item.key] = (await OracleCryptoSwapFactory.deploy(curveLp[item.lp], this.oracles[item.coin0Oracle])) as unknown as IPriceOracle;
    //     }
    // }

    async deployOraclePendlePT() {
        const OraclePendlePTFactory = await ethers.getContractFactory("OraclePendlePT");
        for (let index = 0; index < oraclePendlePTParams.length; index++) {
            const item = oraclePendlePTParams[index];
            const marketAddress = PENDLE_POOLS[item.key].MARKET;
            if (!marketAddress) {
                throw Error(`Key ${item.key} can't be find in PENDLE_POOLS mapping for ${item.oracleName}`);
            }
            const underlyingOracle = this.oracles[item.underlyingOracle];
            if (!underlyingOracle) {
                throw Error(`Underlying oracle ${item.underlyingOracle} can't be find for ${item.oracleName}`);
            }
            this.oracles[item.key] = (await OraclePendlePTFactory.deploy(marketAddress, underlyingOracle, 900, item.decimalsDelta, item.oracleName)) as unknown as IPriceOracle;
        }
    }
}
