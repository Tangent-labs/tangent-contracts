// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TgUSDDeployContext.sol";

import {OracleCoinFromCurveLP} from "../../../src/tgUSD/Oracles/Token/OracleCoinFromCurveLP.sol";
import {OracleDuoPoolStable} from "../../../src/tgUSD/Oracles/CurveLP/OracleDuoPoolStable.sol";
import {OracleTriPoolStable} from "../../../src/tgUSD/Oracles/CurveLP/OracleTriPoolStable.sol";
import {OracleCryptoSwap} from "../../../src/tgUSD/Oracles/CurveLP/OracleCryptoSwap.sol";

import {sDAIOracle} from "../../../src/tgUSD/Oracles/sDAIOracle.sol";

import {OraclePTToken} from "../../../src/tgUSD/Oracles/Pendle/OraclePTToken.sol";

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

        irCalculator = new IRCalculator(owner, controlTower, tgUSDOracle, tgUSD);
        controlTower.toggleIRCalculator(address(irCalculator));

        rewardAccumulator = new RewardAccumulator(owner, controlTower, tgUSDOracle);

        vm.label(address(rewardAccumulator), "RewardAccumulator");

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
        vm.label(address(marketCreator), "MarketCreator");

        vm.stopPrank();
        setupChainlinkOracles();
        setupSimpleTokenOraclesWithCurveLP();
        setupCurveStableLPOracles();
        setupCurveTriCryptoSwapLPOracles();
        setupPendleTokens();
    }

    function setupTgUSDOracle() public {
        vm.startPrank(owner);
        tgUSDOracle.add_price_pair(address(lpDeploymentContext.tgUSDLPs("tgUSD-USDC")));
        tgUSDOracle.add_price_pair(address(lpDeploymentContext.tgUSDLPs("tgUSD-wfrxUSD")));

        pegKeeperRegulator = IPegKeeperRegulator(deployCode("PegKeeperRegulator", abi.encode(tgUSD, tgUSDOracle, feeTreasury, owner, owner)));
        pegKeeperTgUSD_USDC = IPegKeeperV2(deployCode("PegKeeperV2", abi.encode(lpDeploymentContext.tgUSDLPs("tgUSD-USDC"), 20000, pegKeeperRegulator, owner)));
        pegKeeperTgUSD_frxUSD = IPegKeeperV2(deployCode("PegKeeperV2", abi.encode(lpDeploymentContext.tgUSDLPs("tgUSD-wfrxUSD"), 20000, pegKeeperRegulator, owner)));
        address[] memory pairs = new address[](2);
        pairs[0] = address(pegKeeperTgUSD_USDC);
        pairs[1] = address(pegKeeperTgUSD_frxUSD);

        pegKeeperRegulator.add_peg_keepers(pairs);
        vm.stopPrank();
    }

    function setupChainlinkOracles() internal {
        oracles[AddrClassicERC20.TOKEN_USDC] = IPriceOracle(AddrChainlinkOracle.USDC);
        vm.label(address(AddrChainlinkOracle.USDC), "Oracle USDC");

        oracles[AddrClassicERC20.TOKEN_USDT] = IPriceOracle(AddrChainlinkOracle.USDT);
        vm.label(address(AddrChainlinkOracle.USDT), "Oracle USDT");

        oracles[AddrClassicERC20.TOKEN_CRVUSD] = IPriceOracle(AddrChainlinkOracle.CRVUSD);
        vm.label(address(AddrChainlinkOracle.CRVUSD), "Oracle crvUSD");

        oracles[AddrClassicERC20.TOKEN_GHO] = IPriceOracle(AddrChainlinkOracle.GHO);
        vm.label(address(AddrChainlinkOracle.GHO), "Oracle GHO");

        oracles[AddrClassicERC20.TOKEN_WETH] = IPriceOracle(AddrChainlinkOracle.ETH);
        vm.label(address(AddrChainlinkOracle.ETH), "Oracle ETH");

        oracles[AddrClassicERC20.TOKEN_WBTC] = IPriceOracle(AddrChainlinkOracle.BTC);
        vm.label(address(AddrChainlinkOracle.BTC), "Oracle BTC");

        oracles[AddrClassicERC20.TOKEN_CBBTC] = IPriceOracle(AddrChainlinkOracle.CB_BTC);
        vm.label(address(AddrChainlinkOracle.CB_BTC), "Oracle cbBTC");

        oracles[AddrClassicERC20.TOKEN_CRV] = IPriceOracle(AddrChainlinkOracle.CRV);
        vm.label(address(AddrChainlinkOracle.CRV), "Oracle CRV");

        // TODO Warning, is flagged as HIGH MARKET RISK
        oracles[AddrClassicERC20.TOKEN_USR] = IPriceOracle(AddrChainlinkOracle.USR);
        vm.label(address(AddrChainlinkOracle.USR), "Oracle USR");
    }

    function setupSimpleTokenOraclesWithCurveLP() internal {
        // Oracle FXUSD
        oracles[AddrClassicERC20.TOKEN_FXUSD] = new OracleCoinFromCurveLP(address(AddrCurveStableLP.USDC_FXUSD), IPriceOracle(address(AddrChainlinkOracle.USDC)));
        vm.label(address(oracles[AddrClassicERC20.TOKEN_FXUSD]), "Oracle fxUSD");

        // Oracle frxETH
        oracles[AddrClassicERC20.TOKEN_FRXETH] = new OracleCoinFromCurveLP(address(AddrCurveStableLP.FRXETH_WETH), IPriceOracle(address(AddrChainlinkOracle.ETH)));
        vm.label(address(oracles[AddrClassicERC20.TOKEN_FRXETH]), "Oracle frxETH");

        // Oracle pxETH
        oracles[AddrClassicERC20.TOKEN_PXETH] = new OracleCoinFromCurveLP(address(AddrCurveStableLP.PXETH_WETH), IPriceOracle(address(AddrChainlinkOracle.ETH)));
        vm.label(address(oracles[AddrClassicERC20.TOKEN_PXETH]), "Oracle pxETH");

        // Oracle RLP
        oracles[AddrClassicERC20.TOKEN_RLP] = new OracleCoinFromCurveLP(address(AddrCryptoSwapLP.USR_RLP), IPriceOracle(address(AddrChainlinkOracle.USR)));
        vm.label(address(oracles[AddrClassicERC20.TOKEN_RLP]), "Oracle RLP");

        // TODO Warning, is flagged as HIGH MARKET RISK
        oracles[AddrClassicERC20.TOKEN_CVX] = new OracleCoinFromCurveLP(address(AddrCryptoSwapLP.CVX_ETH), IPriceOracle(address(AddrChainlinkOracle.ETH)));
        vm.label(address(oracles[AddrClassicERC20.TOKEN_CVX]), "Oracle CVX");
    }

    function setupCurveTriCryptoSwapLPOracles() internal {
        // Oracle USDT_WBTC_ETH
        oracles[AddrCryptoSwapLP.USDT_WBTC_ETH] = new OracleCryptoSwap(AddrCryptoSwapLP.USDT_WBTC_ETH, AddrChainlinkOracle.USDT);
        vm.label(address(oracles[AddrCryptoSwapLP.USDT_WBTC_ETH]), "Oracle LP USDT/WBTC/ETH");

        // Oracle USDC_WBTC_ETH
        oracles[AddrCryptoSwapLP.USDC_WBTC_ETH] = new OracleCryptoSwap(AddrCryptoSwapLP.USDC_WBTC_ETH, AddrChainlinkOracle.USDC);
        vm.label(address(oracles[AddrCryptoSwapLP.USDC_WBTC_ETH]), "Oracle LP USDC/WBTC/ETH");

        // Oracle CRVUSD_ETH_CRV
        oracles[AddrCryptoSwapLP.CRVUSD_ETH_CRV] = new OracleCryptoSwap(AddrCryptoSwapLP.CRVUSD_ETH_CRV, AddrChainlinkOracle.CRVUSD);
        vm.label(address(oracles[AddrCryptoSwapLP.CRVUSD_ETH_CRV]), "Oracle LP crvUSD/ETH/CRV");

        // Oracle GHO_CBBTC_ETH
        oracles[AddrCryptoSwapLP.GHO_CBBTC_ETH] = new OracleCryptoSwap(AddrCryptoSwapLP.GHO_CBBTC_ETH, AddrChainlinkOracle.GHO);
        vm.label(address(oracles[AddrCryptoSwapLP.GHO_CBBTC_ETH]), "Oracle LP GHO/cbBTC/ETH");

        // Oracle USR_RLP
        oracles[AddrCryptoSwapLP.USR_RLP] = new OracleCryptoSwap(AddrCryptoSwapLP.USR_RLP, AddrChainlinkOracle.USR);
        vm.label(address(oracles[AddrCryptoSwapLP.USR_RLP]), "Oracle LP USR/RLP");

        // Oracle CVX_ETH
        oracles[AddrCryptoSwapLP.CVX_ETH] = new OracleCryptoSwap(AddrCryptoSwapLP.CVX_ETH, AddrChainlinkOracle.ETH);
        vm.label(address(oracles[AddrCryptoSwapLP.CVX_ETH]), "Oracle LP CVX/ETH");
    }

    function setupCurveStableLPOracles() internal {
        // Oracle CRVUSD_USDC
        oracles[AddrCurveStableLP.CRVUSD_USDC] = new OracleDuoPoolStable(
            AddrCurveStableLP.CRVUSD_USDC,
            IPriceOracle(address(AddrChainlinkOracle.USDC)),
            IPriceOracle(address(AddrChainlinkOracle.CRVUSD))
        );
        vm.label(address(oracles[AddrCurveStableLP.CRVUSD_USDC]), "Oracle LP crvUSD/USDC");

        // Oracle CRVUSD_USDT
        oracles[AddrCurveStableLP.CRVUSD_USDT] = new OracleDuoPoolStable(
            AddrCurveStableLP.CRVUSD_USDT,
            IPriceOracle(address(AddrChainlinkOracle.USDT)),
            IPriceOracle(address(AddrChainlinkOracle.CRVUSD))
        );
        vm.label(address(oracles[AddrCurveStableLP.CRVUSD_USDT]), "Oracle LP crvUSD/USDT");

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

    function setupPendleTokens() internal {
        // Oracle PT USDE
        oracles[AddrPTPendle.SUSDE_31_07_2025] = new OraclePTToken(AddrMarketPendle.SUSDE_31_07_2025);
        vm.label(address(oracles[AddrPTPendle.SUSDE_31_07_2025]), "Oracle PT SUSDe 31/07/25");
    }
}
