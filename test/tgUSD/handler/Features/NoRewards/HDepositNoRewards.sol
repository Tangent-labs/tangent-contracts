// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "../../Base/HMarketBase.sol";

import "../../../../../src/tgUSD/Market/MarketNoRewards.sol";

contract HDepositNoRewards is HMarketBase {
    MarketNoRewards marketNoRewards;
    constructor(address _sender, MarketNoRewards _market) HandlerBase(_sender, _market) {
        marketNoRewards = MarketNoRewards(address(_market));
    }
    function deposit(address _for, uint256 lpDeposited, bool isStaked) external handler {
        uint256 balanceCollateralBefore = _beforeDepositCheck(_for, lpDeposited);

        marketNoRewards.deposit(_for, lpDeposited, isStaked);

        _afterDepositCheck(_for, lpDeposited, balanceCollateralBefore);
    }

    function depositAndBorrow(uint256 lpDeposited, uint256 borrowedAmount, bool isStaked) external handler {
        uint256 balanceCollateralBefore = _beforeDepositCheck(sender, lpDeposited);
        (uint256 lastDebt, uint256 interests, uint256 newDebtIndex, uint256 positionDebt, ) = _beforBorrowOrRepayCheck(marketNoRewards);
        _beforeBorrowCheck(marketNoRewards, sender, borrowedAmount);

        marketNoRewards.depositAndBorrow(lpDeposited, borrowedAmount, isStaked);

        _afterDepositCheck(sender, lpDeposited, balanceCollateralBefore);
        _afterBorrowCheck(marketNoRewards, borrowedAmount, lastDebt, interests, newDebtIndex, positionDebt);
    }

    function _beforeDepositCheck(address _for, uint256 collatDeposited) internal returns (uint256 balanceCollateralBefore) {
        IERC20 collatToken = marketNoRewards.collatToken();

        collatToken.approve(address(marketNoRewards), MAX_UINT);

        balanceCollateralBefore = marketNoRewards.collateralBalances(_for);

        verifyLostERC20(collatToken, sender, collatDeposited, "Collat is deposited by sender");

        verifyReceiveERC20(collatToken, address(marketNoRewards), collatDeposited, "Collat is received by the Market");
    }

    function _afterDepositCheck(address _for, uint256 collatDeposited, uint256 balanceCollateralBefore) internal view {
        assertEq(
            collatDeposited,
            marketNoRewards.collateralBalances(_for) - balanceCollateralBefore,
            "Collateral of the user is increased by taking into account pending soc fee"
        );
    }
}
