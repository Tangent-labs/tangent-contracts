import {ethers} from "hardhat";
import {curveLp, chainlinkPriceFeed} from "defi-resources";
import {ERC20, IAggregatorStablePriceV3, IPriceOracle} from "../../../../typechain-types";
import {BaseContext} from "./BaseContext";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {LpDeployContext} from "./LPDeployContext";

// export type OracleKey =
//     | "crvUSD"
//     | "USDC"
//     | "USDC"
//     | "USDT"
//     | "ETH"
//     | "USR"
//     | "GHO"
//     | "fxUSD"
//     | "frxETH"
//     | "crvUSD_USDC"
//     | "crvUSD_USDT"
//     | "USDC_fxUSD"
//     | "frxETH_WETH"
//     | "USDT_WBTC_ETH"
//     | "USDC_WBTC_ETH"
//     | "crvUSD_ETH_CRV"
//     | "GHO_CBBTC_ETH"
//     | "CVX_ETH"
//     | "USR_RLP";

export class OracleContext {
    tgUSDOracle!: IAggregatorStablePriceV3;
    oracles: {[key in string]: IPriceOracle} = {};

    async deployAndSetupOracles(baseContext: BaseContext, lpDeployContext: LpDeployContext) {
        this.oracles["crvUSD"] = await ethers.getContractAt("IPriceOracle", chainlinkPriceFeed.CHAINLINK_crvUSD_USD);
        this.oracles["USDC"] = await ethers.getContractAt("IPriceOracle", chainlinkPriceFeed.CHAINLINK_USDC_USD);
        this.oracles["USDT"] = await ethers.getContractAt("IPriceOracle", chainlinkPriceFeed.CHAINLINK_USDT_USD);
        this.oracles["ETH"] = await ethers.getContractAt("IPriceOracle", chainlinkPriceFeed.CHAINLINK_ETH_USD);
        this.oracles["USR"] = await ethers.getContractAt("IPriceOracle", chainlinkPriceFeed.CHAINLINK_USR_USD);
        this.oracles["GHO"] = await ethers.getContractAt("IPriceOracle", chainlinkPriceFeed.CHAINLINK_GHO_USD);

        this.oracles["BTC"] = await ethers.getContractAt("IPriceOracle", chainlinkPriceFeed.CHAINLINK_BTC_USD);
        this.oracles["cbBTC"] = await ethers.getContractAt("IPriceOracle", chainlinkPriceFeed.CHAINLINK_cbBTC_USD);

        const OracleCoinFromCurveLPFactory = await ethers.getContractFactory("OracleCoinFromCurveLP");
        this.oracles["fxUSD"] = (await OracleCoinFromCurveLPFactory.deploy(curveLp.CRV_LP_USDC_fxUSD, this.oracles["USDC"])) as unknown as IPriceOracle;
        this.oracles["frxETH"] = (await OracleCoinFromCurveLPFactory.deploy(curveLp.CRV_LP_WETH_frxETH, this.oracles["ETH"])) as unknown as IPriceOracle;
        this.oracles["pxETH"] = (await OracleCoinFromCurveLPFactory.deploy(curveLp.CRV_LP_pxETH_WETH, this.oracles["ETH"])) as unknown as IPriceOracle;

        const OracleDuoPoolStableFactory = await ethers.getContractFactory("OracleDuoPoolStable");
        // Stable USD
        this.oracles["crvUSD_USDC"] = (await OracleDuoPoolStableFactory.deploy(curveLp.crvUSD_USDC, this.oracles["USDC"], this.oracles["crvUSD"])) as unknown as IPriceOracle;
        this.oracles["crvUSD_USDT"] = (await OracleDuoPoolStableFactory.deploy(curveLp.crvUSD_USDT, this.oracles["USDT"], this.oracles["crvUSD"])) as unknown as IPriceOracle;
        this.oracles["USDC_fxUSD"] = (await OracleDuoPoolStableFactory.deploy(curveLp.CRV_LP_USDC_fxUSD, this.oracles["USDC"], this.oracles["fxUSD"])) as unknown as IPriceOracle;

        // Stable ETH
        this.oracles["frxETH_WETH"] = (await OracleDuoPoolStableFactory.deploy(curveLp.CRV_LP_WETH_frxETH, this.oracles["ETH"], this.oracles["frxETH"])) as unknown as IPriceOracle;
        this.oracles["pxETH_WETH"] = (await OracleDuoPoolStableFactory.deploy(curveLp.CRV_LP_pxETH_WETH, this.oracles["ETH"], this.oracles["pxETH"])) as unknown as IPriceOracle;

        // Stable BTC
        this.oracles["cbBTC_WBTC"] = (await OracleDuoPoolStableFactory.deploy(curveLp.CRV_DUO_cbBTC_WBTC, this.oracles["cbBTC"], this.oracles["BTC"])) as unknown as IPriceOracle;
        // this.oracles["WBTC_tBTC"] = (await OracleDuoPoolStableFactory.deploy(curveLp.CRV_DUO_WBTC_tBTC, this.oracles["BTC"], this.oracles["tBTC"])) as unknown as IPriceOracle;

        const OracleCryptoSwapFactory = await ethers.getContractFactory("OracleCryptoSwap");
        // Tri Pools
        this.oracles["USDT_WBTC_WETH"] = (await OracleCryptoSwapFactory.deploy(curveLp.CRV_TRI_CRYPTO_USDT, this.oracles["USDT"])) as unknown as IPriceOracle;
        this.oracles["USDC_WBTC_WETH"] = (await OracleCryptoSwapFactory.deploy(curveLp.CRV_TRI_CRYPTO_USDC, this.oracles["USDC"])) as unknown as IPriceOracle;
        this.oracles["crvUSD_ETH_CRV"] = (await OracleCryptoSwapFactory.deploy(curveLp.CRV_TRI_CRYPTO_CRV, this.oracles["crvUSD"])) as unknown as IPriceOracle;
        this.oracles["GHO_cbBTC_WETH"] = (await OracleCryptoSwapFactory.deploy(curveLp.CRV_TRI_GHO_cbBTC_ETH, this.oracles["GHO"])) as unknown as IPriceOracle;
        // Duo Pools

        this.oracles["CVX_ETH"] = (await OracleCryptoSwapFactory.deploy(curveLp.CRV_DUO_ETH_CVX, this.oracles["ETH"])) as unknown as IPriceOracle;
        this.oracles["USR_RLP"] = (await OracleCryptoSwapFactory.deploy(curveLp.CRV_DUO_USR_RLP, this.oracles["USR"])) as unknown as IPriceOracle;

        this.tgUSDOracle = (await (
            await ethers.getContractFactory("AggregatorStablePriceV3")
        ).deploy(baseContext.tgUSD, "1000000000000000", baseContext.owner)) as unknown as IAggregatorStablePriceV3;
        await this.tgUSDOracle.waitForDeployment();

        await this.tgUSDOracle.connect(baseContext.owner).add_price_pair(lpDeployContext.stableLp["tgUSD-USDC"]);
        await this.tgUSDOracle.connect(baseContext.owner).add_price_pair(lpDeployContext.stableLp["tgUSD-wfrxUSD"]);
    }
}
