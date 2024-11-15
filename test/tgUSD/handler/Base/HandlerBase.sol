// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "../../../utils/AssertERC20.sol";
import "../../../../src/tgUSD/Market/Convex/ConvexCrvLPMarket.sol";
abstract contract HandlerBase is AssertERC20 {
    address public sender;
    ConvexCrvLPMarket public market;

    constructor(address _sender, ConvexCrvLPMarket _market) {
        market = _market;
        sender = _sender;
    }

    function setMsgSender(address _sender) external {
        sender = _sender;
    }

    function setMarketRewards(ConvexCrvLPMarket _market) external {
        market = _market;
    }

    modifier handler() {
        vm.startPrank(sender);
        _;
        assertERC20Tracking();
        vm.stopPrank();
    }
}
