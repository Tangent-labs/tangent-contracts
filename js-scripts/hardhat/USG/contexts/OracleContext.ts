import { CHAINLINK_PRICE_FEEDS, COMMON_ERC20S, CURVE_LPS, PENDLE_POOLS } from "@tangent/defi-resources";
import { ZeroAddress } from "ethers";
import { ethers } from "hardhat";
import { PROD_ADDRESSES } from "../../../../ignition/prod_addresses";
import { IAggregatorStablePriceV3, IPriceOracle } from "../../../../typechain-types";
import { chainlinkOracleParams, oracleCoinFromCurveLPParams, oracleDuoPoolStableParams, oracleERC4626Params, oraclePendlePTParams } from "./oracleParams";

export class OracleContext {
    USGOracle!: IAggregatorStablePriceV3;
    oracles: { [key: string]: IPriceOracle } = {};
    oraclesChainlink: { [key: string]: IPriceOracle } = {};
    oraclesCoinFromCurveLP: { [key: string]: IPriceOracle } = {};
    oracles4626: { [key: string]: IPriceOracle } = {};
    oraclesDuoPoolStable: { [key: string]: IPriceOracle } = {};
    oraclesPendlePT: { [key: string]: IPriceOracle } = {};

    async fetchUSGOracleAndDeployMarketOracles() {
        this.USGOracle = await ethers.getContractAt("AggregatorStablePriceV3", PROD_ADDRESSES.USG_ORACLE)

        const chainlinkProd = PROD_ADDRESSES.ORACLES.CHAINLINK
        for (const key of Object.keys(chainlinkProd) as Array<keyof typeof chainlinkProd>) {
            const oracle = await ethers.getContractAt("IPriceOracle", chainlinkProd[key])
            this.oracles[key] = oracle
            this.oraclesChainlink[key] = oracle
        }

        const oracleCoinFromCurveLP = PROD_ADDRESSES.ORACLES.COIN_FROM_CURVE_LP
        for (const key of Object.keys(oracleCoinFromCurveLP) as Array<keyof typeof oracleCoinFromCurveLP>) {
            const oracle = await ethers.getContractAt("IPriceOracle", oracleCoinFromCurveLP[key])
            this.oracles[key] = oracle
            this.oraclesCoinFromCurveLP[key] = oracle
        }

        const duoPoolStable = PROD_ADDRESSES.ORACLES.CURVE_LP_STABLE_DUO
        for (const key of Object.keys(duoPoolStable) as Array<keyof typeof duoPoolStable>) {
            const oracle = await ethers.getContractAt("IPriceOracle", duoPoolStable[key])
            this.oracles[key] = oracle
            this.oraclesDuoPoolStable[key] = oracle
        }


        await this.deployChainlinkWrappers();
        await this.deployOracleCoinFromCurveLP();
        await this.deployOracleCoinERC4626();
        await this.deployOracleDuoPoolStable();

        // await this.deployOracleCryptoSwap();
        await this.deployOraclePendlePT();
    }


    async deployChainlinkWrappers() {
        const ChainlinkWrapperFactory = await ethers.getContractFactory("OracleChainlinkWrapper");

        for (let index = 0; index < chainlinkOracleParams.length; index++) {
            const item = chainlinkOracleParams[index];
            const oracle = await ChainlinkWrapperFactory.deploy(
                await ethers.getContractAt("IPriceOracle", CHAINLINK_PRICE_FEEDS[item.oracleName]),
                10000000000,
                ZeroAddress,
                item.oracleName
            );
            this.oracles[item.key] = oracle
            this.oraclesChainlink[item.key] = oracle
        }
    }

    async deployOracleCoinFromCurveLP() {
        const OracleCoinFromCurveLPFactory = await ethers.getContractFactory("OracleCoinFromCurveLP");

        for (let index = 0; index < oracleCoinFromCurveLPParams.length; index++) {
            const item = oracleCoinFromCurveLPParams[index];
            const curveLP = CURVE_LPS[item.lp];
            const otherStableOracle = this.oracles[item.otherStableOracle];

            if (!curveLP) {
                throw Error(`ERC4626 ${item.lp} not configured in defi-resources in CURVE_LPS for ${item.oracleName}`);
            }

            if (!otherStableOracle) {
                throw Error(`Oracle0 ${item.otherStableOracle} not deployed for ${item.oracleName}`);
            }

            const oracle = (await OracleCoinFromCurveLPFactory.deploy(curveLP, otherStableOracle, item.isReversed, item.key)) as unknown as IPriceOracle;
            this.oracles[item.key] = oracle
            this.oraclesCoinFromCurveLP[item.key] = oracle

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
            const oracle = (await OracleERC4626Factory.deploy(erc4626Address, underlyingOracle, item.oracleName)) as unknown as IPriceOracle;
            this.oracles[item.erc4626] = oracle
            this.oracles4626[item.erc4626] = oracle
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
            const oracle = (await OracleDuoPoolStableFactory.deploy(lpAddress, oracle0, oracle1, item.oracleName)) as unknown as IPriceOracle;

            this.oracles[item.key] = oracle
            this.oraclesDuoPoolStable[item.key] = oracle

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
            const oracle = (await OraclePendlePTFactory.deploy(marketAddress, underlyingOracle, 900, item.decimalsDelta, item.oracleName)) as unknown as IPriceOracle;
            this.oracles[item.key] = oracle
            this.oraclesPendlePT[item.key] = oracle

        }
    }
}
