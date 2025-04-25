// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import "../../../../../src/interfaces/externals/Curve/ICrvPoolPlain.sol";
import "../../../../../src/interfaces/externals/Chainlink/IAggregatorV3.sol";
import "../../../handler/Curve/HLpManipulator.sol";
import "forge-std/console.sol";

contract GetOracleERC4626Price is MarketDeploymentContext {
    IERC4626[] erc4626s;

    function setUp() external {
        erc4626s.push(AddrERC4626.sDAI);
        erc4626s.push(AddrERC4626.sUSDe);
        erc4626s.push(AddrERC4626.sUSDS);
        erc4626s.push(AddrERC4626.scrvUSD);
        erc4626s.push(AddrERC4626.sDOLA);
        erc4626s.push(AddrERC4626.wstUSR);
        erc4626s.push(AddrERC4626.sfrxUSD);
    }

    function test_verify_stable_saving_account_price() external view {
        for (uint256 i; i < erc4626s.length; i++) {
            IERC4626 erc4626 = erc4626s[i];
            IPriceOracle oracle = oracles[erc4626];
            assertNotEq(address(oracle), address(0), "Oracle not config");
            uint256 pps = erc4626.convertToAssets(1e18);

            uint256 oracleValue = oracles[erc4626].latestAnswer();

            assertApproxEqRel(pps, oracleValue, 1e15); // Each savings price is approximatly equals to their oracleValue

            assertGt(oracleValue, 1.04 ether); // All these saving earned more than 4% in index
            assertLt(oracleValue, 1.2 ether); // None of these savings earned more than 20% in index
        }
    }
}
