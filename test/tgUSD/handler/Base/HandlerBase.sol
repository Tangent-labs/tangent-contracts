// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "../../../utils/AssertERC20.sol";
import "../../../../src/tgUSD/Market/abstract/MarketExternalActions.sol";
abstract contract HandlerBase is AssertERC20 {
    address public sender;
    MarketExternalActions public market;

    constructor(address _sender, MarketExternalActions _market) {
        market = _market;
        sender = _sender;
    }

    function setMsgSender(address _sender) external {
        sender = _sender;
    }

    modifier handler() {
        vm.startPrank(sender);
        _;
        assertERC20Tracking();
        vm.stopPrank();
    }
}
