// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../../../src/interfaces/externals/Curve/ICrvPoolPlain.sol";
import "../../../../../src/interfaces/externals/Chainlink/IAggregatorV3.sol";
import "../../../handler/Curve/HLpManipulator.sol";
import "forge-std/console.sol";

contract GetPriceFromStableCurveLP is MarketDeploymentContext {
    IERC20Metadata[] stablecoins;
    IERC20Metadata[] ethsLike;
    IERC20Metadata[] btcsLike;

    function setUp() external {
        stablecoins.push(AddrClassicERC20.fxUSD);
        stablecoins.push(AddrClassicERC20.frxUSD);
        stablecoins.push(AddrClassicERC20.DOLA);

        ethsLike.push(AddrClassicERC20.frxETH);
        ethsLike.push(AddrClassicERC20.pxETH);

        btcsLike.push(AddrClassicERC20.eBTC);
    }

    function test_verify_stable_price_through_crv_lp() external view {
        for (uint256 i = 0; i < stablecoins.length; i++) {
            IERC20Metadata stable = stablecoins[i];
            IPriceOracle oracle = oracles[stable];
            assertNotEq(address(oracle), address(0), "Oracle not config");

            assertApproxEqRel(1e18, oracle.latestAnswer(), 7e14); // 0.05% from 1$
        }
    }

    function test_verify_liquidETH_price_through_crv_lp() external view {
        uint256 ethPrice = oracles[AddrClassicERC20.WETH].latestAnswer() * 10 ** (18 - oracles[AddrClassicERC20.WETH].decimals());
        for (uint256 i = 0; i < ethsLike.length; i++) {
            IERC20Metadata ethLike = ethsLike[i];
            IPriceOracle oracle = oracles[ethLike];
            assertNotEq(address(oracle), address(0), "Oracle not config");

            uint256 ethLikePrice = oracle.latestAnswer();
            assertApproxEqRel(ethPrice, ethLikePrice, 3e15); // 0.3% from ethPrice
            assertLt(ethLikePrice, ethPrice, "Almost always true as its liquidStaking");
        }
    }

    function test_verify_BTC_price_through_crv_lp() external view {
        uint256 btcPrice = oracles[AddrClassicERC20.WBTC].latestAnswer() * 10 ** (18 - oracles[AddrClassicERC20.WBTC].decimals());
        for (uint256 i = 0; i < btcsLike.length; i++) {
            IPriceOracle oracle = oracles[btcsLike[i]];
            assertNotEq(address(oracle), address(0), "Oracle not config");

            uint256 btcLikePrice = oracle.latestAnswer();
            assertApproxEqRel(btcPrice, btcLikePrice, 3e15); // 0.3% from btc price
            assertLt(btcLikePrice, btcPrice, "Almost always true as its liquidStaking");
        }
    }
}
