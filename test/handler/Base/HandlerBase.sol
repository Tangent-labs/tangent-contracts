// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "../../utils/AssertERC20.sol";
import "../../../src/USG/Market/abstract/MarketExternalActions.sol";
import "../../../src/USG/Utilities/MarketViewer.sol";

abstract contract HandlerBase is AssertERC20 {
    address public sender;
    MarketExternalActions public market;
    MarketViewer public marketViewer;
    IERC20 public usg;

    constructor(address _sender, MarketExternalActions _market, IERC20 _usg, MarketViewer _marketViewer) {
        market = _market;
        sender = _sender;
        usg = _usg;
        marketViewer = _marketViewer;
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
