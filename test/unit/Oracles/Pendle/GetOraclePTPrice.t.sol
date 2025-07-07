// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract GetOraclePTPrice is MarketDeploymentContext {
    IERC20Metadata[] pendlePTs;

    function setUp() external {
        pendlePTs.push(AddrPTPendle.sUSDe_31_07_25);
        pendlePTs.push(AddrPTPendle.eUSDe_29_05_25);
        pendlePTs.push(AddrPTPendle.eBTC_26_06_25);
    }

    function test_determine_PT_price() external {
        for (uint256 i = 0; i < pendlePTs.length; i++) {
            IERC20Metadata pt = pendlePTs[i];
            uint256 oracleValue = oracles[pt].latestAnswer();
        }

        skip(365 days);

        for (uint256 i = 0; i < pendlePTs.length; i++) {
            IERC20Metadata pt = pendlePTs[i];
            uint256 oracleValueBeforeSwap = oracles[pt].latestAnswer();

            (, IPriceOracle underlyingOracle, uint96 decimals) = OraclePendlePT(address(oracles[pt])).params();

            assertEq(underlyingOracle.latestAnswer() * 10 ** (18 - decimals), oracleValueBeforeSwap);
        }
    }
}
