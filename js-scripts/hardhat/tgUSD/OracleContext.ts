import {ethers} from "hardhat";
import {curveLp} from "convergence-defi-tools";
import {AddressLike} from "ethers";
import {CurveStableLPOracle, IAggregatorV3, StablePriceOracleParams} from "../../../typechain-types";

const LP_USDC_FXUSD = "0x5018BE882DccE5E3F2f3B0913AE2096B9b3fB61f";

export class OracleContext {
    tgUSD!: StablePriceOracleParams;
    crvUSD!: IAggregatorV3;
    usdc!: IAggregatorV3;
    usdt!: IAggregatorV3;
    fxUSD!: StablePriceOracleParams;
    crvUSD_USDC!: CurveStableLPOracle;

    async deployAndSetupOracles(tgUSD_USDC_LP: AddressLike) {
        this.crvUSD = await ethers.getContractAt("IAggregatorV3", "0xEEf0C605546958c1f899b6fB336C20671f9cD49F");
        this.usdc = await ethers.getContractAt("IAggregatorV3", "0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6");
        this.usdt = await ethers.getContractAt("IAggregatorV3", "0x3E7d1eAB13ad0104d2750B8863b489D65364e32D");

        const StablePriceOracleParamsFactory = await ethers.getContractFactory("StablePriceOracleParams");
        this.tgUSD = await StablePriceOracleParamsFactory.deploy(tgUSD_USDC_LP, this.usdc);
        this.fxUSD = await StablePriceOracleParamsFactory.deploy(LP_USDC_FXUSD, this.usdc);

        const CurveStableLPOracleFactory = await ethers.getContractFactory("CurveStableLPOracle");
        this.crvUSD_USDC = await CurveStableLPOracleFactory.deploy(curveLp.CRVUSD_USDC, this.crvUSD, this.usdc);
    }
}
