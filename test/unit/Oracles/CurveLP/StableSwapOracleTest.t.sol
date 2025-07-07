// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../handler/Curve/HLPManipulator.sol";

contract StableSwapOracleTest is MarketDeploymentContext {
    ICurveStableSwapNG[] stablePools;

    function setUp() external {
        stablePools.push(AddrCurveStableLP.USDT_crvUSD);
        stablePools.push(AddrCurveStableLP.USDC_crvUSD);
        stablePools.push(AddrCurveStableLP.frxUSD_sUSDS);
        stablePools.push(AddrCurveStableLP.scrvUSD_sDOLA);
        stablePools.push(AddrCurveStableLP.sUSDS_USDT);
        stablePools.push(AddrCurveStableLP.sDAI_sUSDe);

        stablePools.push(AddrCurveStableLP.cbBTC_WBTC);

        stablePools.push(AddrCurveStableLP.WETH_frxETH);
        stablePools.push(AddrCurveStableLP.WETH_pxETH);
    }
    /// WARNING THIS IS ONLY USED FOR TESTING PURPOSE
    /// THIS METHOD CAN BE MANIPULATED IN PROD
    function approximateLPValue(ICurveStableSwapNG pool) public view returns (uint256) {
        uint256 totalSupply = pool.totalSupply();

        return (approximateTotalLPValue(pool) * 1e18) / totalSupply;
    }

    function approximateTotalLPValue(ICurveStableSwapNG lp) public view returns (uint256) {
        uint256 usdValue;
        for (uint256 i = 0; i < 5; i++) {
            IERC20Metadata coin;

            try lp.coins(i) {
                coin = IERC20Metadata(lp.coins(i));
            } catch {
                break;
            }

            IPriceOracle oracle = oracles[coin];
            assertNotEq(address(oracle), address(0), "Coin oracle not setup");
            uint256 price = oracle.latestAnswer() * 10 ** (18 - oracle.decimals());

            usdValue += (price * lp.balances(i) * (10 ** (18 - coin.decimals()))) / 1e18;
        }
        return usdValue;
    }

    function test_atomic_verification() external view {
        for (uint256 i = 0; i < stablePools.length; i++) {
            ICurveStableSwapNG lp = ICurveStableSwapNG(stablePools[i]);
            uint256 approx = approximateLPValue(lp);

            IPriceOracle lpOracle = oracles[lp];
            assertNotEq(address(lpOracle), address(0), "LP Oracle not setup");
            uint256 lpOraclePrice = oracles[lp].latestAnswer();
            assertApproxEqRel(approx, lpOraclePrice, 10e15); // 1% maximum
        }
    }
}
