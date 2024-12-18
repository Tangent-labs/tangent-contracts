// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TgUSDDeployContext.sol";

import {StablePriceOracleParams} from "../../../src/tgUSD/Oracles/Token/StablePriceOracleParams.sol";
import {OracleDuoPoolStable} from "../../../src/tgUSD/Oracles/Pools/OracleDuoPoolStable.sol";
import {OracleTriPoolStable} from "../../../src/tgUSD/Oracles/Pools/OracleTriPoolStable.sol";
import {sDAIOracle} from "../../../src/tgUSD/Oracles/sDAIOracle.sol";

import {IRCalculator} from "../../../src/tgUSD/Utilities/IRCalculator.sol";
contract OraclesContext is TgUSDDeployContext {
    IRCalculator public irCalculator;

    mapping(IERC20 => IPriceOracle) public oracles;

    constructor() {
        vm.label(address(AddrChainlinkOracle.CRVUSD), "Oracle CRVUSD");
        vm.label(address(AddrChainlinkOracle.USDC), "Oracle USDC");
        vm.label(address(AddrChainlinkOracle.USDT), "Oracle USDT");
        // Oracle tgUSD
        oracles[tgUsd] = new StablePriceOracleParams(tgUSDLp, IPriceOracle(address(AddrChainlinkOracle.USDC)));
        vm.label(address(oracles[tgUsd]), "Oracle tgUSD");

        irCalculator = new IRCalculator(owner, oracles[tgUsd]);

        // Oracle FXUSD
        oracles[AddrClassicERC20.TOKEN_FXUSD] = new StablePriceOracleParams(AddrCurveStableLP.USDC_FXUSD, IPriceOracle(address(AddrChainlinkOracle.USDC)));
        vm.label(address(oracles[AddrClassicERC20.TOKEN_FXUSD]), "Oracle fxUSD");

        // Oracle CRVUSD_USDC
        oracles[AddrCurveStableLP.CRVUSD_USDC] = new OracleDuoPoolStable(
            AddrCurveStableLP.CRVUSD_USDC,
            IPriceOracle(address(AddrChainlinkOracle.CRVUSD)),
            IPriceOracle(address(AddrChainlinkOracle.USDC))
        );
        vm.label(address(oracles[AddrCurveStableLP.CRVUSD_USDC]), "Oracle LP crvUSD/USDC");

        // Oracle USDC_FXUSD
        oracles[AddrCurveStableLP.USDC_FXUSD] = new OracleDuoPoolStable(
            AddrCurveStableLP.USDC_FXUSD,
            IPriceOracle(address(AddrChainlinkOracle.USDC)),
            oracles[AddrClassicERC20.TOKEN_FXUSD]
        );

        // Oracle TriStable DAI/USDC/USDT
        oracles[AddrCurveStableLP.TRI_USD_TOKEN] = new OracleTriPoolStable(
            AddrCurveStableLP.TRI_USD_LP,
            IPriceOracle(address(AddrChainlinkOracle.DAI)),
            IPriceOracle(address(AddrChainlinkOracle.USDC)),
            IPriceOracle(address(AddrChainlinkOracle.USDT))
        );
        vm.label(address(oracles[AddrCurveStableLP.USDC_FXUSD]), "Oracle LP USDC/fxUSD");

        // Oracle sDAI
        oracles[AddrERC4626.S_DAI] = new sDAIOracle(AddrChainlinkOracle.SDAI);
        vm.label(address(oracles[AddrERC4626.S_DAI]), "Oracle sDAI");
    }
}
