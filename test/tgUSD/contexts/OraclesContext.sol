// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TgUSDDeployContext.sol";

import {StablePriceOracleParams} from "../../../src/tgUSD/Oracles/Token/StablePriceOracleParams.sol";
import {StablePriceOracleNoParams} from "../../../src/tgUSD/Oracles/Token/StablePriceOracleNoParams.sol";
import {OracleDuoPoolStable} from "../../../src/tgUSD/Oracles/Pools/OracleDuoPoolStable.sol";
import {OracleTriPoolStable} from "../../../src/tgUSD/Oracles/Pools/OracleTriPoolStable.sol";
import {sDAIOracle} from "../../../src/tgUSD/Oracles/sDAIOracle.sol";

import {IRCalculator} from "../../../src/tgUSD/Utilities/IRCalculator.sol";
import {IAggregatorStablePriceV3} from "../../../src/interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";
import {IPegKeeperRegulator} from "../../../src/interfaces/externals/LlamaLend/IPegKeeperRegulator.sol";
import {IPegKeeperV2} from "../../../src/interfaces/externals/LlamaLend/IPegKeeperV2.sol";

contract OraclesContext is TgUSDDeployContext {
    IRCalculator public irCalculator;
    mapping(IERC20 => IPriceOracle) public oracles;

    IAggregatorStablePriceV3 public tgUSDOracle;

    IPegKeeperRegulator public pegKeeperRegulator;

    IPegKeeperV2 public pegKeeperTgUSD_USDC;
    IPegKeeperV2 public pegKeeperTgUSD_frxUSD;

    constructor() {
        vm.startPrank(owner);
        // Oracle tgUSD

        tgUSDOracle = IAggregatorStablePriceV3(deployCode("AggregatorStablePriceV3", abi.encode(tgUSD, uint256(1000000000000000), owner)));
        vm.label(address(tgUSDOracle), "Oracle tgUSD");

        irCalculator = new IRCalculator(owner, controlTower, tgUSDOracle);

        rewardAccumulator = new RewardAccumulator(owner, controlTower, irCalculator);

        marketCreator = new MarketCreator(
            owner,
            controlTower,
            tgUSD,
            irCalculator,
            rewardAccumulator,
            liquidatorProxy,
            convexCrvLPMarketImplem,
            convexFxnLPMarketImplem,
            marketNoSociabilizationImplem
        );
        controlTower.toggleMarketCreator(address(marketCreator));

        vm.stopPrank();
        setupChainlinkOracles();
        setupSimpleTokenOraclesWithCurveLP();
        setupCurveStableLPOracles();
    }

    function setupTgUSDOracle() public {
        tgUSDOracle.add_price_pair(address(lpDeploymentContext.tgUSDLPs("tgUSD-USDT")));
        tgUSDOracle.add_price_pair(address(lpDeploymentContext.tgUSDLPs("tgUSD-wfrxUSD")));

        pegKeeperRegulator = IPegKeeperRegulator(deployCode("PegKeeperRegulator", abi.encode(tgUSD, tgUSDOracle, feeTreasury, owner, owner)));

        pegKeeperTgUSD_USDC = IPegKeeperV2(deployCode("PegKeeperV2", abi.encode(lpDeploymentContext.tgUSDLPs("tgUSD-USDC"), 20000, pegKeeperRegulator, owner)));
        pegKeeperTgUSD_frxUSD = IPegKeeperV2(deployCode("PegKeeperV2", abi.encode(lpDeploymentContext.tgUSDLPs("tgUSD-wfrxUSD"), 20000, pegKeeperRegulator, owner)));

        address[] memory pairs = new address[](2);
        pairs[0] = address(pegKeeperTgUSD_USDC);
        pairs[1] = address(pegKeeperTgUSD_frxUSD);

        pegKeeperRegulator.add_peg_keepers(pairs);
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
