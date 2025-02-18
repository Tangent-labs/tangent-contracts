import {ethers} from "hardhat";
import {curveLp} from "defi-resources";
import {ERC20, IAggregatorStablePriceV3, IPriceOracle} from "../../../../typechain-types";
import {BaseContext} from "./BaseContext";
import {HardhatEthersSigner} from "@nomicfoundation/hardhat-ethers/signers";
import {LpDeployContext} from "./LPDeployContext";

export class OracleContext {
    tgUSDOracle!: IAggregatorStablePriceV3;
    oracles: {[key: string]: IPriceOracle} = {};

    async deployAndSetupOracles(baseContext: BaseContext, lpDeployContext: LpDeployContext) {
        this.oracles["crvUSD"] = await ethers.getContractAt("IPriceOracle", "0xEEf0C605546958c1f899b6fB336C20671f9cD49F");
        this.oracles["USDC"] = await ethers.getContractAt("IPriceOracle", "0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6");
        this.oracles["USDT"] = await ethers.getContractAt("IPriceOracle", "0x3E7d1eAB13ad0104d2750B8863b489D65364e32D");

        const StablePriceOracleParamsFactory = await ethers.getContractFactory("StablePriceOracleParams");
        this.oracles["fxUSD"] = (await StablePriceOracleParamsFactory.deploy(curveLp.CRV_LP_USDC_fxUSD, this.oracles["USDC"])) as unknown as IPriceOracle;

        const OracleDuoPoolStableFactory = await ethers.getContractFactory("OracleDuoPoolStable");
        this.oracles["crvUSD_USDC"] = (await OracleDuoPoolStableFactory.deploy(curveLp.crvUSD_USDC, this.oracles["USDC"], this.oracles["crvUSD"])) as unknown as IPriceOracle;
        this.oracles["crvUSD_USDT"] = (await OracleDuoPoolStableFactory.deploy(curveLp.crvUSD_USDT, this.oracles["USDT"], this.oracles["crvUSD"])) as unknown as IPriceOracle;
        this.oracles["USDC_fxUSD"] = (await OracleDuoPoolStableFactory.deploy(curveLp.CRV_LP_USDC_fxUSD, this.oracles["USDC"], this.oracles["fxUSD"])) as unknown as IPriceOracle;
        this.oracles["frxETH_WETH"] = (await OracleDuoPoolStableFactory.deploy(curveLp.FRXETH_ETH_LP, this.oracles["USDT"], this.oracles["crvUSD"])) as unknown as IPriceOracle;

        this.tgUSDOracle = (await (
            await ethers.getContractFactory("AggregatorStablePriceV3")
        ).deploy(baseContext.tgUSD, "1000000000000000", baseContext.owner)) as unknown as IAggregatorStablePriceV3;
        await this.tgUSDOracle.waitForDeployment();

        await this.tgUSDOracle.connect(baseContext.owner).add_price_pair(lpDeployContext.stableLp["tgUSD-USDC"]);
        await this.tgUSDOracle.connect(baseContext.owner).add_price_pair(lpDeployContext.stableLp["tgUSD-frxUSD"]);
    }
}
