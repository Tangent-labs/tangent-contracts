// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TgUSDDeployContext.sol";

import "../../../src/tgUSD/Oracles/tgUSDOracle.sol";
import "../../../src/tgUSD/Oracles/StableUSDOracle.sol";
import "../../../src/tgUSD/Oracles/CurveStableLPOracle.sol";

contract OraclesContext is TgUSDDeployContext {
    mapping(IERC20 => IPriceOracle) public oracles;

    constructor() {
        // Oracle tgUSD
        oracles[tgUsd] = new tgUSDOracle(tgUSDLp, IPriceOracle(address(AddrChainlinkOracle.USDC)), 6);
        vm.label(address(rewardAccumulator), "Oracle tgUSD");

        // Oracle FXUSD
        oracles[AddrClassicERC20.TOKEN_FXUSD] = new StableUSDOracle(AddrCurveStableLP.USDC_FXUSD, IPriceOracle(address(AddrChainlinkOracle.USDC)), 6);
        vm.label(address(rewardAccumulator), "Oracle fxUSD");

        // Oracle CRVUSD_USDC
        oracles[AddrCurveStableLP.CRVUSD_USDC] = new CurveStableLPOracle(AddrCurveStableLP.CRVUSD_USDC, AddrChainlinkOracle.CRVUSD, AddrChainlinkOracle.USDC);
        vm.label(address(rewardAccumulator), "Oracle LP crvUSD/USDC");
    }
}
