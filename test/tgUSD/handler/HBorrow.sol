// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "forge-std/Test.sol";

import "../../../src/tgUSD/Market/Market.sol";
import "../../utils/AssertERC20.sol";

contract HBorrow is AssertERC20 {
    address public sender;
    Market public market;

    constructor(address _sender, Market _market) {
        market = _market;
        sender = _sender;
    }

    function setMsgSender(address _sender) external {
        sender = _sender;
    }

    function setMarketRewards(Market _market) external {
        market = _market;
    }

    function borrow(address receiver, uint256 borrowedAmount) external {
        vm.startPrank(sender);

        uint256 mintableInterests = market.mintableInterests();
        uint256 lastDebt = market.lastDebt();
        uint256 positionDebt = market.positionDebt(sender);
        uint256 positionDebtIndex = market.positionDebtIndex(sender);
        uint256 lastIR = market.lastIR();

        uint256 increaseCoeff = ((lastIR * (block.timestamp - market.blockLastIRTimestamp())) * RAY) / 365 days;
        uint256 interests = (increaseCoeff * lastDebt) / RAY;

        uint256 newDebtIndex = market.debtIndex() + increaseCoeff;

        uint256 newPositionDebtIndex = ((positionDebt + borrowedAmount) * RAY) / newDebtIndex;

        verifyReceiveERC20(market.tgUSD(), receiver, borrowedAmount, "tgUSD borrowed is received by receiver");

        market.borrow(receiver, borrowedAmount);

        assertGe(market.lastDebt() - lastDebt, borrowedAmount, "Total new bebt didn't decrease");

        assertEq(market.positionDebtIndex(sender), newPositionDebtIndex, "New position debt index updated");
        assertEq(market.debtIndex(), newDebtIndex, "New total debt index incremented");
        assertEq(market.mintableInterests(), mintableInterests + interests, "New interests increments mintableInterests");

        assertERC20Tracking();

        vm.stopPrank();
    }
}
