// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../../../src/interfaces/externals/Curve/ICrvPoolPlain.sol";
import "../../../../../src/interfaces/externals/Chainlink/IAggregatorV3.sol";
import "../../../handler/Curve/HLpManipulator.sol";
import "forge-std/console.sol";

contract GetOraclePTPrice is MarketDeploymentContext {
    IERC20Metadata[] pendlePTs;

    function setUp() external {
        pendlePTs.push(AddrPTPendle.sUSDe_31_07_25);
        pendlePTs.push(AddrPTPendle.eUSDe_29_05_25);
        pendlePTs.push(AddrPTPendle.eBTC_26_06_25);
    }

    function test_determine_PT_price() external view {
        for (uint256 i = 0; i < pendlePTs.length; i++) {
            IERC20Metadata pt = pendlePTs[i];
            uint256 oracleValueBeforeSwap = oracles[pt].latestAnswer();

            console.log(oracleValueBeforeSwap);

            //TODO Verify these assert. The price of the Lp should for me change
            // uint256 newApprox = approximateLPValue(lp);
            // skip(80000);
            // lp.price_oracle(0);
            // lp.price_oracle(1);
            // assertEq(oracleValueAfterSwap, oracles[lp].latestAnswer(), "After some time, oracle pricing should change");
            // assertApproxEqRel(newApprox, oracles[lp].latestAnswer(), 3e15, "After some time the price should have change");
        }
    }
}
