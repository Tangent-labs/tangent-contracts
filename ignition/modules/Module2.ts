import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { PROD_ADDRESSES } from "../prod_addresses";
import { CHAINLINK_PRICE_FEEDS, REDSTONE_PRICE_FEEDS } from "@tangent/defi-resources";
import { STATIC_CONFIG_CONVEX_CURVE } from "../../js-scripts/hardhat/USG/config/market";

export default buildModule("Module2", (m) => {
    const irCalculator = m.contract("IRCalculator", [PROD_ADDRESSES.OWNER, PROD_ADDRESSES.CONTROL_TOWER, PROD_ADDRESSES.USG_ORACLE, PROD_ADDRESSES.USG]);
    const rewardAccumulator = m.contract("RewardAccumulator", [PROD_ADDRESSES.OWNER, PROD_ADDRESSES.CONTROL_TOWER, PROD_ADDRESSES.USG_ORACLE]);
    const marketCreator = m.contract("MarketCreator", [
        PROD_ADDRESSES.OWNER,
        PROD_ADDRESSES.CONTROL_TOWER,
        PROD_ADDRESSES.USG,
        irCalculator,
        rewardAccumulator,
        PROD_ADDRESSES.ZAPPING_PROXY,
        PROD_ADDRESSES.CONVEX_CRV_LP_MARKET,
        PROD_ADDRESSES.CONVEX_FXN_LP_MARKET,
        PROD_ADDRESSES.BASIC_ERC20_MARKET,
    ]);

    const usdcRedstoneFallback = m.contract("OracleRedstoneWrapperFallback", [REDSTONE_PRICE_FEEDS.USDC_USD], { id: "USDC_REDSTONE" });
    const usdtRedstoneFallback = m.contract("OracleRedstoneWrapperFallback", [REDSTONE_PRICE_FEEDS.USDT_USD], { id: "USDT_REDSTONE" });

    const usdcOracle = m.contract("OracleChainlinkWrapper", [CHAINLINK_PRICE_FEEDS.USDC_USD, 82800, usdcRedstoneFallback], { id: "USDC" });
    const usdtOracle = m.contract("OracleChainlinkWrapper", [CHAINLINK_PRICE_FEEDS.USDT_USD, 86400, usdtRedstoneFallback], { id: "USDT" });

    const param = STATIC_CONFIG_CONVEX_CURVE["USDC_USDT"]
    const usdcUsdtLpOracle = m.contract("OracleDuoPoolStable", [param.collatToken, usdcOracle, usdtOracle], { id: "USDC_USDT_ORACLE" });

    const pendlePTRouter = m.contract("PendlePTRouter", []);
    return { irCalculator, rewardAccumulator, marketCreator, pendlePTRouter, usdcUsdtLpOracle };
});