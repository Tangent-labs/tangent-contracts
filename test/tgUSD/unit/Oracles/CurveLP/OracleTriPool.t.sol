// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../../../src/interfaces/externals/Curve/ICrvPoolPlain.sol";
import "../../../../../src/interfaces/externals/Chainlink/IAggregatorV3.sol";
contract OracleTriPool is MarketDeploymentContext {
    function setUp() public {}

    function test_pricing_tripool() external view {
        assertGt(oracles[AddrCurveStableLP.TRI_USD_TOKEN].latestAnswer(), 1030008992481998133);
    }
}
