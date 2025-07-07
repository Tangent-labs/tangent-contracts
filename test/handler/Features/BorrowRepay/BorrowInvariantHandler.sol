// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";

import "../../../../src/USG/Market/abstract/MarketExternalActions.sol";

contract BorrowInvariantHandler is Test {
    MarketExternalActions[] public markets;

    IERC20 public USG;

    constructor(MarketExternalActions[] memory _markets, IERC20 _USG) {
        USG = _USG;
        for (uint256 index = 0; index < _markets.length; index++) {
            markets.push(_markets[index]);
        }
    }

    function deposit(address _for, uint256 depositedAmount, bool isStaked) public {
        skip(pickRandomDuration());
        MarketExternalActions _market = pickRandomMarket();
        vm.startPrank(msg.sender);
        IERC20 _collatToken = _market.collatToken();

        depositedAmount = bound(depositedAmount, 1, 100_000 ether);

        deal(address(_collatToken), msg.sender, depositedAmount);

        _collatToken.approve(address(_market), depositedAmount);
        _market.deposit(msg.sender, depositedAmount, isStaked);

        vm.stopPrank();
    }

    function repay(address account, uint256 USGToRepay, address callerZapper) public {
        skip(pickRandomDuration());

        MarketExternalActions _market = pickRandomMarket();
        vm.startPrank(msg.sender);

        uint256 userDebt = _market.userDebt(msg.sender);

        if (userDebt == 0) {
            bool depositOrRepay = vm.randomBool();
            if (depositOrRepay) {
                deposit(msg.sender, USGToRepay, vm.randomBool());
                return;
            } else {
                borrow(msg.sender, USGToRepay);
                return;
            }
        }

        bool isFullRepay = vm.randomBool();
        USGToRepay = isFullRepay ? userDebt : bound(USGToRepay, 1, userDebt - _market.minimumLoan());
        deal(address(USG), msg.sender, USGToRepay);

        _market.repay(msg.sender, USGToRepay);
        vm.stopPrank();
    }

    function borrow(address receiver, uint256 borrowedAmount) public {
        skip(pickRandomDuration());

        MarketExternalActions _market = pickRandomMarket();
        vm.startPrank(msg.sender);

        uint256 maxBorrowAmount = _market.maxBorrowable(msg.sender);
        uint256 actualDebt = _market.userDebt(msg.sender);
        if (maxBorrowAmount == 0) {
            bool depositOrRepay = vm.randomBool();
            if (depositOrRepay) {
                deposit(msg.sender, borrowedAmount, vm.randomBool());
                return;
            } else {
                repay(msg.sender, borrowedAmount, address(0));
                return;
            }
        } else {
            uint256 minLoan = _market.minimumLoan();
            uint256 low;
            if (actualDebt >= minLoan) {
                low = 1;
            } else {
                low = minLoan - actualDebt;
            }
            if (low > maxBorrowAmount) {
                deposit(msg.sender, 0, false);
                return;
            }
            borrowedAmount = bound(borrowedAmount, low, maxBorrowAmount);
            _market.borrow(msg.sender, borrowedAmount);
        }

        vm.stopPrank();
    }

    function pickRandomMarket() public returns (MarketExternalActions) {
        uint256 randomIndex = vm.randomUint();
        randomIndex = bound(randomIndex, 0, markets.length - 1);
        return markets[randomIndex];
    }

    function pickRandomDuration() public returns (uint256) {
        uint256 randomDuration = vm.randomUint();
        randomDuration = bound(randomDuration, 0, 10 days);
        return randomDuration;
    }
}
