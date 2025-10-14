// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../../src/chainview/USG/ui/GetBalancesWithVsTan.cv.sol";

contract GetBalancesWithVsTanChainview is MarketDeploymentContext {
    // LIST
    function test_getBalancesAllowancesWithVsTan_ui_returns() public {
        IERC20[] memory tokens = new IERC20[](3);
        tokens[0] = usg;
        tokens[1] = sUSG;
        tokens[2] = tan;
        try new GetBalancesWithVsTan(usr1, tokens, vsTan) {} catch (bytes memory reason) {
            GetBalancesWithVsTan.TokenBalance[] memory result = abi.decode(removeFirst4Bytes(reason), (GetBalancesWithVsTan.TokenBalance[]));
            for (uint256 i; i < result.length; i++) {
                console.log(address(result[i].token), result[i].balance);
            }
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}
