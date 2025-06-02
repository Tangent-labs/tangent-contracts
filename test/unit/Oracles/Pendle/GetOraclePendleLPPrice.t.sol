// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract GetOraclePendleLPPrice is MarketDeploymentContext {
    IERC20Metadata[] pendleLPs;

    function setUp() external {
        pendleLPs.push(AddrMarketPendle.sUSDe_31_07_25);
        pendleLPs.push(AddrMarketPendle.eUSDe_29_05_25);
        pendleLPs.push(AddrMarketPendle.eBTC_26_06_25);
    }

    function test_determine_LP_price() external {
        for (uint256 i = 0; i < pendleLPs.length; i++) {
            IERC20Metadata lp = pendleLPs[i];
            uint256 oracleValue = oracles[lp].latestAnswer();

            console.log(pendleLPs[i].symbol(), oracleValue);
        }

        skip(1000);

        for (uint256 i = 0; i < pendleLPs.length; i++) {
            IERC20Metadata lp = pendleLPs[i];
            uint256 oracleValue = oracles[lp].latestAnswer();

            console.log(pendleLPs[i].symbol(), oracleValue);
        }
    }
}
