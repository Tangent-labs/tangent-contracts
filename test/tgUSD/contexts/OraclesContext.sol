// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TgUSDDeployContext.sol";

import {StablePriceOracleParams} from "../../../src/tgUSD/Oracles/Token/StablePriceOracleParams.sol";
import {StablePriceOracleNoParams} from "../../../src/tgUSD/Oracles/Token/StablePriceOracleNoParams.sol";
import {OracleDuoPoolStable} from "../../../src/tgUSD/Oracles/Pools/OracleDuoPoolStable.sol";
import {OracleTriPoolStable} from "../../../src/tgUSD/Oracles/Pools/OracleTriPoolStable.sol";
import {sDAIOracle} from "../../../src/tgUSD/Oracles/sDAIOracle.sol";

import {IRCalculator} from "../../../src/tgUSD/Utilities/IRCalculator.sol";
contract OraclesContext is TgUSDDeployContext {
    IRCalculator public irCalculator;

    mapping(IERC20 => IPriceOracle) public oracles;

    constructor() {
        // Oracle tgUSD
        oracles[tgUsd] = new StablePriceOracleParams(tgUSD_USDC_Lp, IPriceOracle(address(AddrChainlinkOracle.USDC)));
        vm.label(address(oracles[tgUsd]), "Oracle tgUSD");

        irCalculator = new IRCalculator(owner, controlTower, oracles[tgUsd]);
        marketCreator = new MarketCreator(
            owner,
            controlTower,
            tgUsd,
            irCalculator,
            rewardAccumulator,
            liquidatorProxy,
            convexCrvLPMarketImplem,
            convexFxnLPMarketImplem,
            marketNoSociabilizationImplem
        );

        vm.prank(owner);
        controlTower.toggleMarketCreator(address(marketCreator));

        setupChainlinkOracles();
        setupSimpleTokenOraclesWithCurveLP();
        setupCurveStableLPOracles();
    }

    function setupChainlinkOracles() internal {
        vm.label(address(AddrChainlinkOracle.CRVUSD), "Oracle CRVUSD");
        vm.label(address(AddrChainlinkOracle.USDC), "Oracle USDC");
        vm.label(address(AddrChainlinkOracle.USDT), "Oracle USDT");
        vm.label(address(AddrChainlinkOracle.ETH), "Oracle ETH");
    }

    function setupSimpleTokenOraclesWithCurveLP() internal {
        // Oracle FXUSD
        oracles[AddrClassicERC20.TOKEN_FXUSD] = new StablePriceOracleParams(AddrCurveStableLP.USDC_FXUSD, IPriceOracle(address(AddrChainlinkOracle.USDC)));
        vm.label(address(oracles[AddrClassicERC20.TOKEN_FXUSD]), "Oracle fxUSD");

        // Oracle frxETH
        oracles[AddrClassicERC20.TOKEN_FRXETH] = new StablePriceOracleNoParams(AddrCurveStableLP.FRXETH_WETH, IPriceOracle(address(AddrChainlinkOracle.ETH)));
        vm.label(address(oracles[AddrClassicERC20.TOKEN_FRXETH]), "Oracle frxETH");

        // Oracle pxETH
        oracles[AddrClassicERC20.TOKEN_PXETH] = new StablePriceOracleParams(AddrCurveStableLP.PXETH_WETH, IPriceOracle(address(AddrChainlinkOracle.ETH)));
        vm.label(address(oracles[AddrClassicERC20.TOKEN_PXETH]), "Oracle pxETH");
    }

    function setupCurveStableLPOracles() internal {
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
        vm.label(address(oracles[AddrCurveStableLP.USDC_FXUSD]), "Oracle LP USDC/fxUSD");

        // Oracle TriStable DAI/USDC/USDT
        oracles[AddrCurveStableLP.TRI_USD_TOKEN] = new OracleTriPoolStable(
            AddrCurveStableLP.TRI_USD_LP,
            IPriceOracle(address(AddrChainlinkOracle.DAI)),
            IPriceOracle(address(AddrChainlinkOracle.USDC)),
            IPriceOracle(address(AddrChainlinkOracle.USDT))
        );
        vm.label(address(oracles[AddrCurveStableLP.TRI_USD_TOKEN]), "Oracle LP TriUSD");

        // Oracle frxETH/WETH
        oracles[AddrCurveStableLP.FRXETH_WETH] = new OracleDuoPoolStable(
            AddrCurveStableLP.FRXETH_WETH,
            IPriceOracle(address(AddrChainlinkOracle.ETH)),
            oracles[AddrClassicERC20.TOKEN_FRXETH]
        );
        vm.label(address(oracles[AddrCurveStableLP.FRXETH_WETH]), "Oracle LP frxETH/ETH");

        // Oracle pxETH/WETH
        oracles[AddrCurveStableLP.PXETH_WETH] = new OracleDuoPoolStable(
            AddrCurveStableLP.PXETH_WETH,
            IPriceOracle(address(AddrChainlinkOracle.ETH)),
            oracles[AddrClassicERC20.TOKEN_PXETH]
        );
        vm.label(address(oracles[AddrCurveStableLP.PXETH_WETH]), "Oracle LP pxETH/ETH");
    }

    function setupSavingAccountOracles() internal {
        // Oracle sDAI
        oracles[AddrERC4626.S_DAI] = new sDAIOracle(AddrChainlinkOracle.SDAI);
        vm.label(address(oracles[AddrERC4626.S_DAI]), "Oracle sDAI");
    }
}
