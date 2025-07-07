// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Features/BorrowRepay/HBorrow.sol";

import "../../handler/Features/BorrowRepay/HBorrow.sol";

import "../../../src/chainview/USG/ui/GetBalancesAllowances.cv.sol";

contract GetBalancesAllowancesChainview is MarketDeploymentContext {
    InputBalancesAllowances[] public ibas;

    // LIST
    function test_getBalancesAllowances_ui_returns() public {
        address[] memory spenders = new address[](1);
        spenders[0] = usr1;
        ibas.push(InputBalancesAllowances({token: IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), spenders: spenders}));

        try new GetBalancesAllowances(usr1, ibas) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}
