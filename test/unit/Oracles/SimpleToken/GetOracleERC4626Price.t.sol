// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

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

        IERC4626 strangeDecimalsErc4626 = new Mock4626();
        oracles[strangeDecimalsErc4626] = new OracleERC4626(strangeDecimalsErc4626, oracles[AddrClassicERC20.USDC], "Zaza");

        erc4626s.push(strangeDecimalsErc4626);
    }

    function test_verify_stable_saving_account_price() external view {
        for (uint256 i; i < erc4626s.length; i++) {
            IERC4626 erc4626 = erc4626s[i];
            IPriceOracle oracle = oracles[erc4626];
            assertNotEq(address(oracle), address(0), "Oracle not config");
            uint256 pps = erc4626.convertToAssets(1e18);

            uint256 oracleValue = oracles[erc4626].latestAnswer(true);

            assertApproxEqRel(pps, oracleValue, 50e14); // Each savings price is approximatly equals to their oracleValue

            assertGt(oracleValue, 0.99 ether); // All these saving earned more than 4% in index
            assertLt(oracleValue, 1.4 ether); // None of these savings earned more than 40% in index
        }
    }
}

contract Mock4626 is ERC4626 {
    constructor() ERC20("", "") ERC4626(AddrClassicERC20.USDC) {}
}
