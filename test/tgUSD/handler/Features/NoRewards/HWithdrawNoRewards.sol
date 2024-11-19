// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "../../Base/HMarketBase.sol";

import "../../../../../src/tgUSD/Market/MarketNoRewards.sol";

contract HWithdrawNoRewards is HMarketBase {
    MarketNoRewards marketNoRewards;
    constructor(address _sender, MarketNoRewards _market) HandlerBase(_sender, _market) {
        marketNoRewards = MarketNoRewards(address(_market));
    }
    function withdraw(uint256 lpToWithdraw) external handler {
        // (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) = _beforeWithdrawCheck(lpToWithdraw);

        marketNoRewards.withdraw(lpToWithdraw);

        // _afterWithdrawCheck(lpToWithdraw, totalCollateralBefore, balanceCollateralBefore);
    }

    function withdrawAndRepay(uint256 lpToWithdraw, uint256 debtRepay) external handler {
        // (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) = _beforeWithdrawCheck(lpToWithdraw);

        marketNoRewards.withdrawAndRepay(lpToWithdraw, debtRepay);

        // _afterWithdrawCheck(lpToWithdraw, totalCollateralBefore, balanceCollateralBefore);
    }

    // function _beforeWithdrawCheck(uint256 lpToWithdraw) internal returns (uint256 totalCollateralBefore, uint256 balanceCollateralBefore) {
    //     IERC20 collatToken = marketFxnLP.collatToken();

    //     totalCollateralBefore = marketFxnLP.totalCollateral();
    //     balanceCollateralBefore = marketFxnLP.collateralBalances(sender);

    //     verifyReceiveERC20(collatToken, sender, lpToWithdraw, "Collat is withdrawn and sent to sender");

    //     // TODO Verify withdraw occurs properly by withdrawing first non staked assets
    // }

    // function _afterWithdrawCheck(uint256 lpToWithdraw, uint256 totalCollateralBefore, uint256 balanceCollateralBefore) internal view {
    //     assertEq(marketFxnLP.totalCollateral(), totalCollateralBefore - lpToWithdraw, "Total collateral is decreased by the amount withdrawn");
    //     assertEq(marketFxnLP.collateralBalances(sender), balanceCollateralBefore - lpToWithdraw, "Collateral of the user is decreased by the amount withdrawn");
    // }
}
