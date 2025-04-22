import {ethers} from "hardhat";
import {curveLp, chainlinkPriceFeed} from "defi-resources";
import {IAggregatorStablePriceV3, IPriceOracle} from "../../../../typechain-types";
import {BaseContext} from "./BaseContext";
import {LpDeployContext} from "./LPDeployContext";

export class OracleContext {
    tgUSDOracle!: IAggregatorStablePriceV3;
    oracles: {[key: string]: IPriceOracle} = {};
    chainlinkOracleParams = [
        // Stable USD
        {key: "crvUSD", oracleName: "CHAINLINK_crvUSD_USD"},
        {key: "USDC", oracleName: "CHAINLINK_USDC_USD"},
        {key: "FRAX", oracleName: "CHAINLINK_FRAX_USD"},
        {key: "USDT", oracleName: "CHAINLINK_USDT_USD"},
        {key: "USR", oracleName: "CHAINLINK_USR_USD"},
        {key: "GHO", oracleName: "CHAINLINK_GHO_USD"},
        {key: "USDe", oracleName: "CHAINLINK_USDe_USD"},
        // ETH
        {key: "ETH", oracleName: "CHAINLINK_ETH_USD"},
        {key: "stETH", oracleName: "CHAINLINK_stETH_USD"},
        // BTC
        {key: "BTC", oracleName: "CHAINLINK_BTC_USD"},
        {key: "cbBTC", oracleName: "CHAINLINK_cbBTC_USD"},
    ];

    oracleCoinFromCurveLPParams = [
        {key: "frxUSD", lp: "CRV_DUO_FRAX_frxUSD", coin0Oracle: "FRAX"},
        {key: "fxUSD", lp: "CRV_LP_USDC_fxUSD", coin0Oracle: "USDC"},
        {key: "frxETH", lp: "CRV_LP_WETH_frxETH", coin0Oracle: "ETH"},
        {key: "pxETH", lp: "CRV_LP_pxETH_WETH", coin0Oracle: "ETH"},
    ];

    oracleDuoPoolStableParams = [
        // USD
        {key: "crvUSD_USDC", lp: "crvUSD_USDC", coin0Oracle: "USDC", coin1Oracle: "crvUSD"},
        {key: "crvUSD_USDT", lp: "crvUSD_USDT", coin0Oracle: "USDT", coin1Oracle: "crvUSD"},
        {key: "USDC_fxUSD", lp: "CRV_LP_USDC_fxUSD", coin0Oracle: "USDC", coin1Oracle: "fxUSD"},
        {key: "USDC_USDT", lp: "CRV_DUO_USDC_USDT", coin0Oracle: "USDC", coin1Oracle: "USDT"},
        {key: "frxUSD_USDe", lp: "CRV_DUO_frxUSD_USDe", coin0Oracle: "frxUSD", coin1Oracle: "USDe"},
        // ETH
        {key: "frxETH_WETH", lp: "CRV_LP_WETH_frxETH", coin0Oracle: "ETH", coin1Oracle: "frxETH"},
        {key: "pxETH_WETH", lp: "CRV_LP_pxETH_WETH", coin0Oracle: "ETH", coin1Oracle: "ETH"},
        {key: "pxETH_stETH", lp: "CRV_LP_pxETH_stETH", coin0Oracle: "pxETH", coin1Oracle: "stETH"},
        // BTC
        {key: "cbBTC_WBTC", lp: "CRV_DUO_cbBTC_WBTC", coin0Oracle: "cbBTC", coin1Oracle: "BTC"},
    ];

    oracleCryptoSwapParams = [
        // TRI
        {key: "USDT_WBTC_WETH", lp: "CRV_TRI_CRYPTO_USDT", coin0Oracle: "USDT"},
        {key: "USDC_WBTC_WETH", lp: "CRV_TRI_CRYPTO_USDC", coin0Oracle: "USDC"},
        {key: "crvUSD_ETH_CRV", lp: "CRV_TRI_CRYPTO_CRV", coin0Oracle: "crvUSD"},
        {key: "GHO_cbBTC_WETH", lp: "CRV_TRI_GHO_cbBTC_ETH", coin0Oracle: "GHO"},
        // DUO
        {key: "CVX_ETH", lp: "CRV_DUO_ETH_CVX", coin0Oracle: "ETH"},
        {key: "USR_RLP", lp: "CRV_DUO_USR_RLP", coin0Oracle: "USR"},
    ];
    async fetchChainlinkOracle() {
        for (let index = 0; index < this.chainlinkOracleParams.length; index++) {
            const item = this.chainlinkOracleParams[index];
            this.oracles[item.key] = await ethers.getContractAt("IPriceOracle", chainlinkPriceFeed[item.oracleName]);
        }
    }

    async deployOracleCoinFromCurveLP() {
        const OracleCoinFromCurveLPFactory = await ethers.getContractFactory("OracleCoinFromCurveLP");

        for (let index = 0; index < this.oracleCoinFromCurveLPParams.length; index++) {
            const item = this.oracleCoinFromCurveLPParams[index];
            this.oracles[item.key] = (await OracleCoinFromCurveLPFactory.deploy(curveLp[item.lp], this.oracles[item.coin0Oracle])) as unknown as IPriceOracle;
        }
    }

    async deployOracleDuoPoolStable() {
        const OracleDuoPoolStableFactory = await ethers.getContractFactory("OracleDuoPoolStable");

        for (let index = 0; index < this.oracleDuoPoolStableParams.length; index++) {
            const item = this.oracleDuoPoolStableParams[index];
            const oracle0 = this.oracles[item.coin0Oracle];
            this.oracles[item.key] = (await OracleDuoPoolStableFactory.deploy(curveLp[item.lp], oracle0, this.oracles[item.coin1Oracle])) as unknown as IPriceOracle;
        }
    }

    async deployOracleCryptoSwap() {
        const OracleCryptoSwapFactory = await ethers.getContractFactory("OracleCryptoSwap");

        for (let index = 0; index < this.oracleCryptoSwapParams.length; index++) {
            const item = this.oracleCryptoSwapParams[index];
            this.oracles[item.key] = (await OracleCryptoSwapFactory.deploy(curveLp[item.lp], this.oracles[item.coin0Oracle])) as unknown as IPriceOracle;
        }
    }

    async deployAndSetupOracles(baseContext: BaseContext, lpDeployContext: LpDeployContext) {
        await this.fetchChainlinkOracle();
        await this.deployOracleCoinFromCurveLP();
        await this.deployOracleDuoPoolStable();
        await this.deployOracleCryptoSwap();

        this.tgUSDOracle = (await (
            await ethers.getContractFactory("AggregatorStablePriceV3")
        ).deploy(baseContext.tgUSD, "1000000000000000", baseContext.owner)) as unknown as IAggregatorStablePriceV3;
        await this.tgUSDOracle.waitForDeployment();

        await this.tgUSDOracle.connect(baseContext.owner).add_price_pair(lpDeployContext.stableLp["tgUSD-USDC"]);
        await this.tgUSDOracle.connect(baseContext.owner).add_price_pair(lpDeployContext.stableLp["tgUSD-wfrxUSD"]);
    }
}
