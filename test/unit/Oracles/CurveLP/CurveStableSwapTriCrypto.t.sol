// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockChainlinkOracle} from "../../../mocks/MockChainlinkOracle.sol";
import "../../../contexts/MarketDeploymentContext.sol";
contract CurveStableSwapTriCrypto is MarketDeploymentContext {
    MockChainlinkOracle daiOracle;
    MockChainlinkOracle usdcOracle;
    MockChainlinkOracle usdtOracle;

    OracleTriPoolStable oracleTriUSDC;

    uint256 vp;
    function setUp() public {
        daiOracle = new MockChainlinkOracle(9978941, 7);
        usdcOracle = new MockChainlinkOracle(10045, 4);
        usdtOracle = new MockChainlinkOracle(1001236148444, 12);

        oracleTriUSDC = new OracleTriPoolStable(address(AddrCurveStableLP.TRI_USD_POOL), daiOracle, usdcOracle, usdtOracle);
        vp = AddrCurveStableLP.TRI_USD_POOL.get_virtual_price();
    }

    function test_pricing_tripool_first_price_is_taken() external view {
        assertEq((vp * daiOracle.latestAnswer() * 10 ** (18 - daiOracle.decimals())) / 1e18, oracleTriUSDC.latestAnswer());
    }

    function test_pricing_tripool_second_price_is_taken() external {
        usdcOracle.setLastAnswer(9404);
        assertEq((vp * usdcOracle.latestAnswer() * 10 ** (18 - usdcOracle.decimals())) / 1e18, oracleTriUSDC.latestAnswer());
    }

    function test_pricing_tripool_third_price_is_taken() external {
        usdtOracle.setLastAnswer(981236148444);
        assertEq((vp * usdtOracle.latestAnswer() * 10 ** (18 - usdtOracle.decimals())) / 1e18, oracleTriUSDC.latestAnswer());
    }
}
