// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../../src/chainview/USG/bot/BoostBalancesSnapshots.cv.sol";

contract BoostBalancesSnapshotsTest is MarketDeploymentContext {
    address llamaNFT = 0xe127cE638293FA123Be79C25782a5652581Db234;
    address veCRV = 0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2;
    address vlCVX = 0x72a19342e8F1838460eBFCCEf09F6585e32db86E;
    address veSDT = 0x0C30476f66034E11782938DF8e4384970B6c9e8a;
    address veFXN = 0xEC6B8A3F3605B083F7044C0F31f2cac0caf1d469;
    address vePENDLE = 0x4f30A9D41B80ecC5B94306AB4364951AE3170210;
    address veYFI = 0x90c1f9220d90d3966FbeE24045EDd73E1d588aD5;
    address sINV = 0x08d23468A467d2bb86FaE0e32F247A26C7E2e994;
    address stRESOLV = 0xFE4BCE4b3949c35fB17691D8b03c3caDBE2E5E23;
    address sRSUP = 0x22222222E9fE38F6f1FC8C61b25228adB4D8B953;

    address[] users;
    IERC20[] tokens;

    function setUp() external {
        tokens.push(IERC20(llamaNFT));
        tokens.push(IERC20(veCRV));
        tokens.push(IERC20(veSDT));
        tokens.push(IERC20(veFXN));
        tokens.push(IERC20(vePENDLE));
        tokens.push(IERC20(veYFI));
        tokens.push(IERC20(sINV));
        tokens.push(IERC20(stRESOLV));
        tokens.push(IERC20(sRSUP));

        users.push(0xf8Ed473803bC8D7d9Ea5edbFe79487198B7Ee0FD);
    }
    // LIST
    function test_sUSG_UI_not_connected() public {
        try new BoostBalancesSnapshots(tokens, users) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}
