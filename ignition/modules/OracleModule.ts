import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

import { chainlinkOracleParams, oracleCoinFromCurveLPParams, oracleDuoPoolStableParams, oracleERC4626Params, oraclePendlePTParams, redstonOracles } from "../../js-scripts/hardhat/USG/contexts/oracleParams";
import { commonERC20, curveLp, PendlePools, CHAINLINK_PRICE_FEEDS, REDSTONE_PRICE_FEEDS } from "@tangent/defi-resources";
import { ZeroAddress } from "ethers";
import { PROD_ADDRESSES } from "../prod_addresses";

type StringRecord = Record<string, string>;

export default buildModule("OracleModule", (m) => {
    const erc20s = (commonERC20 as StringRecord)
    const crvLp = (curveLp as StringRecord)

    const oracles: { [name: string]: any } = {}

    // Deploy Redstone fallbacks
    for (let i = 0; i < redstonOracles.length; i++) {
        const param = redstonOracles[i];
        oracles[param.key] = m.contract("OracleRedstoneWrapperFallback", [param.bytesKey], { id: param.key });
    }


    // Deploy Chainlink Wrappers
    for (let i = 0; i < chainlinkOracleParams.length; i++) {
        const param = chainlinkOracleParams[i];
        const fallback = oracles[param.fallbackKey] ? oracles[param.fallbackKey] : ZeroAddress
        oracles[param.key] = m.contract("OracleChainlinkWrapper", [CHAINLINK_PRICE_FEEDS[param.oracleName], param.heatbeat, fallback], { id: param.key });
    }

    // Deploy Oracle based on a Curve LP
    for (let i = 0; i < oracleCoinFromCurveLPParams.length; i++) {
        const param = oracleCoinFromCurveLPParams[i];
        oracles[param.key] = m.contract("OracleCoinFromCurveLP", [crvLp[param.lp], oracles[param.coin0Oracle], param.isReversed], { id: param.key })

    }

    // Deploy ERC4626 Oracle
    for (let i = 0; i < oracleERC4626Params.length; i++) {
        const param = oracleERC4626Params[i];
        const erc4626Address = erc20s[param.erc4626]
        oracles[param.erc4626] = m.contract("OracleERC4626", [erc4626Address, oracles[param.underlyingOracle]], { id: param.erc4626 })
    }

    // Deploy Stable LP Oracle
    for (let i = 0; i < oracleDuoPoolStableParams.length; i++) {
        const param = oracleDuoPoolStableParams[i];
        oracles[param.key] = m.contract("OracleDuoPoolStable", [crvLp[param.lp], oracles[param.coin0Oracle], oracles[param.coin1Oracle]], { id: param.key })
    }

    // Deploy Pendle Oracles
    for (let i = 0; i < oraclePendlePTParams.length; i++) {
        const param = oraclePendlePTParams[i];
        const formattedKey = param.key.replace(' ', '_').replace('/', '_').replace('/', '_')
        oracles[formattedKey] = m.contract("OraclePendlePT", [PendlePools[param.key].MARKET, oracles[param.underlyingOracle], 900, 18], { id: formattedKey })
    }

    return {};

});