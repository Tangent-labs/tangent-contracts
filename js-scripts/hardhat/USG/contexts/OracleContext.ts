import {ethers} from "hardhat";
import {curveLp, PRICE_FEEDS, PendlePools, commonERC20} from "defi-resources";
import {IAggregatorStablePriceV3, IPriceOracle} from "../../../../typechain-types";
import {BaseContext} from "./BaseContext";
import {LpDeployContext} from "./LPDeployContext";

export class OracleContext {
    USGOracle!: IAggregatorStablePriceV3;
    oracles: {[key: string]: IPriceOracle} = {};
    chainlinkOracleParams: {
        key: string;
        oracleName: keyof typeof PRICE_FEEDS;
    }[] = [
        // Stable USD
        {key: "crvUSD", oracleName: "crvUSD_USD"},
        {key: "USDC", oracleName: "USDC_USD"},
        {key: "FRAX", oracleName: "FRAX_USD"},
        {key: "USDT", oracleName: "USDT_USD"},
        {key: "USR", oracleName: "USR_USD"},
        {key: "GHO", oracleName: "GHO_USD"},
        {key: "USDe", oracleName: "USDe_USD"},
        // ETH
        {key: "ETH", oracleName: "ETH_USD"},
        {key: "stETH", oracleName: "stETH_USD"},
        // BTC
        {key: "BTC", oracleName: "BTC_USD"},
        {key: "cbBTC", oracleName: "cbBTC_USD"},
    ];

    oracleERC4626Params = [
        {erc4626: "sUSDe", underlyingOracle: "USDe"},
        {erc4626: "wstUSR", underlyingOracle: "USR"},
    ];

    oracleCoinFromCurveLPParams = [
        {key: "frxUSD", lp: "CRV_DUO_FRAX_frxUSD", coin0Oracle: "FRAX", isReversed: false},
        {key: "fxUSD", lp: "CRV_LP_USDC_fxUSD", coin0Oracle: "USDC", isReversed: false},
        {key: "frxETH", lp: "CRV_LP_WETH_frxETH", coin0Oracle: "ETH", isReversed: false},
        {key: "pxETH", lp: "CRV_LP_pxETH_WETH", coin0Oracle: "ETH", isReversed: false},
    ];

    oracleDuoPoolStableParams = [
        // USD
        {key: "crvUSD-USDC", lp: "crvUSD_USDC", coin0Oracle: "USDC", coin1Oracle: "crvUSD"},
        {key: "crvUSD-USDT", lp: "crvUSD_USDT", coin0Oracle: "USDT", coin1Oracle: "crvUSD"},
        {key: "USDC-fxUSD", lp: "CRV_LP_USDC_fxUSD", coin0Oracle: "USDC", coin1Oracle: "fxUSD"},
        {key: "USDC-USDT", lp: "CRV_DUO_USDC_USDT", coin0Oracle: "USDC", coin1Oracle: "USDT"},
        {key: "frxUSD-USDe", lp: "CRV_DUO_frxUSD_USDe", coin0Oracle: "frxUSD", coin1Oracle: "USDe"},
        // ETH
        {key: "frxETH-WETH", lp: "CRV_LP_WETH_frxETH", coin0Oracle: "ETH", coin1Oracle: "frxETH"},
        {key: "pxETH-WETH", lp: "CRV_LP_pxETH_WETH", coin0Oracle: "ETH", coin1Oracle: "ETH"},
        {key: "pxETH-stETH", lp: "CRV_LP_pxETH_stETH", coin0Oracle: "pxETH", coin1Oracle: "stETH"},
        // BTC
        {key: "cbBTC-WBTC", lp: "CRV_DUO_cbBTC_WBTC", coin0Oracle: "cbBTC", coin1Oracle: "BTC"},
    ];

    oracleCryptoSwapParams = [
        // TRI
        {key: "USDT-WBTC-WETH", lp: "CRV_TRI_CRYPTO_USDT", coin0Oracle: "USDT"},
        {key: "USDC-WBTC-WETH", lp: "CRV_TRI_CRYPTO_USDC", coin0Oracle: "USDC"},
        {key: "crvUSD-ETH-CRV", lp: "CRV_TRI_CRYPTO_CRV", coin0Oracle: "crvUSD"},
        {key: "GHO-cbBTC-WETH", lp: "CRV_TRI_GHO_cbBTC_ETH", coin0Oracle: "GHO"},
        // DUO
        {key: "CVX-ETH", lp: "CRV_DUO_ETH_CVX", coin0Oracle: "ETH"},
        {key: "USR-RLP", lp: "CRV_DUO_USR_RLP", coin0Oracle: "USR"},
    ];

    oraclePendlePTParams = [
        {key: "sUSDe 07/31/25", underlyingOracle: "USDe"},
        {key: "wstUSR 07/25/25", underlyingOracle: "USR"},

        {key: "sUSDe 09/25/25", underlyingOracle: "sUSDe"},
        {key: "USDe 09/25/25", underlyingOracle: "USDe"},
        {key: "wstUSR 09/25/25", underlyingOracle: "wstUSR"},
        {key: "USR 09/04/25", underlyingOracle: "USR"},
    ];
    async fetchChainlinkOracle() {
        for (let index = 0; index < this.chainlinkOracleParams.length; index++) {
            const item = this.chainlinkOracleParams[index];
            this.oracles[item.key] = await ethers.getContractAt("IPriceOracle", PRICE_FEEDS[item.oracleName]);
        }
    }

    async deployOracleCoinFromCurveLP() {
        const OracleCoinFromCurveLPFactory = await ethers.getContractFactory("OracleCoinFromCurveLP");

        for (let index = 0; index < this.oracleCoinFromCurveLPParams.length; index++) {
            const item = this.oracleCoinFromCurveLPParams[index];
            this.oracles[item.key] = (await OracleCoinFromCurveLPFactory.deploy(curveLp[item.lp], this.oracles[item.coin0Oracle], item.isReversed)) as unknown as IPriceOracle;
        }
    }

    async deployOracleCoinERC4626() {
        const OracleERC4626Factory = await ethers.getContractFactory("OracleERC4626");

        for (let index = 0; index < this.oracleERC4626Params.length; index++) {
            const item = this.oracleERC4626Params[index];
            this.oracles[item.erc4626] = (await OracleERC4626Factory.deploy(commonERC20[item.erc4626], this.oracles[item.underlyingOracle])) as unknown as IPriceOracle;
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

    async deployOraclePendlePT() {
        const OraclePendlePTFactory = await ethers.getContractFactory("OraclePendlePT");

        for (let index = 0; index < this.oraclePendlePTParams.length; index++) {
            const item = this.oraclePendlePTParams[index];
            this.oracles[item.key] = (await OraclePendlePTFactory.deploy(PendlePools[item.key].MARKET, this.oracles[item.underlyingOracle], 900)) as unknown as IPriceOracle;
        }
    }

    async deployAndSetupOracles(baseContext: BaseContext, lpDeployContext: LpDeployContext) {
        await this.fetchChainlinkOracle();
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
        await this.USGOracle.connect(baseContext.owner).add_price_pair(lpDeployContext.stableLp["USG-wfrxUSD"]);
    }
}
