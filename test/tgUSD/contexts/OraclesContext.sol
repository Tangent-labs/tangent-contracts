// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TgUSDDeployContext.sol";

import {StablePriceOracleParams} from "../../../src/tgUSD/Oracles/Curve/StablePriceOracleParams.sol";
import {CurveStableLPOracle} from "../../../src/tgUSD/Oracles/Curve/CurveStableLPOracle.sol";
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
        oracles[AddrCurveStableLP.CRVUSD_USDC] = new CurveStableLPOracle(
            AddrCurveStableLP.CRVUSD_USDC,
            IPriceOracle(address(AddrChainlinkOracle.CRVUSD)),
            IPriceOracle(address(AddrChainlinkOracle.USDC))
        );
        vm.label(address(oracles[AddrCurveStableLP.CRVUSD_USDC]), "Oracle LP crvUSD/USDC");

        // Oracle USDC_FXUSD
        oracles[AddrCurveStableLP.USDC_FXUSD] = new CurveStableLPOracle(
            AddrCurveStableLP.USDC_FXUSD,
            IPriceOracle(address(AddrChainlinkOracle.USDC)),
            oracles[AddrClassicERC20.TOKEN_FXUSD]
        );
        vm.label(address(oracles[AddrCurveStableLP.USDC_FXUSD]), "Oracle LP USDC/fxUSD");

        // Oracle sDAI
        oracles[AddrERC4626.S_DAI] = new sDAIOracle(AddrChainlinkOracle.SDAI);
        vm.label(address(oracles[AddrERC4626.S_DAI]), "Oracle sDAI");
    }
}
