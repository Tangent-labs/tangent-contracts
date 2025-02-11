// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../contexts/ConvexCurveContext.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../handler/Features/BorrowRepay/HBorrow.sol";

import "../../../src/chainview/tgUSD/ui/GetBalancesAllowances.cv.sol";

contract GetBalancesAllowancesChainview is ConvexCurveContext {
    BalancesAllowances.InputBalancesAllowances[] public ibas;

    // LIST
    function test_getBalancesAllowances_ui_returns() public {
        address[] memory spenders = new address[](1);
        spenders[0] = usr1;
        ibas.push(BalancesAllowances.InputBalancesAllowances({token: AddrClassicERC20.TOKEN_USDC, spenders: spenders}));
        try new GetBalancesAllowances(usr1, ibas) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}
