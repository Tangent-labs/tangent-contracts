// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;
import "forge-std/Test.sol";

import "../../../src/tgUSD/Market/Convex/ConvexCrvLPMarket.sol";
import "../../utils/AssertERC20.sol";

contract HDepositConvexCrvLP is AssertERC20 {
    address public sender;
    ConvexCrvLPMarket public marketRewards;

    constructor(address _sender, ConvexCrvLPMarket _marketRewards) {
        marketRewards = _marketRewards;
        sender = _sender;
    }

    function setMsgSender(address _sender) external {
        sender = _sender;
    }

    function setMarketRewards(ConvexCrvLPMarket _marketRewards) external {
        marketRewards = _marketRewards;
    }

    function deposit(address _for, uint256 lpDeposited, bool isStaked) external {
        IERC20 collatToken = marketRewards.collatToken();
        uint256 socFeePercentage = marketRewards.socFeePercentage();
        uint256 socFeePending = marketRewards.socFeePending();

        vm.startPrank(sender);
        collatToken.approve(address(marketRewards), MAX_UINT);

        uint256 feeToTake;
        uint256 totalCollateralBefore = marketRewards.totalCollateral();
        uint256 balanceCollateralBefore = marketRewards.collateralBalances(_for);

        verifyLostERC20(collatToken, sender, lpDeposited, "Collat is deposited by sender");
        if (isStaked) {
            verifyBalERC20NotChanging(collatToken, address(marketRewards), "Collat is not received by market");
            verifyReceiveERC20(marketRewards.cvxRewardToken(), address(marketRewards), lpDeposited, "Collat is received by the staking contract");
        } else {
            feeToTake = (lpDeposited * socFeePercentage) / 100_000;
            verifyReceiveERC20(collatToken, address(marketRewards), lpDeposited, "Collat is received by the market");
        }

        marketRewards.deposit(_for, lpDeposited, isStaked);

        if (isStaked) {
            assertEq(marketRewards.socFeePending(), 0);
            assertEq(marketRewards.totalCollateral() - totalCollateralBefore, lpDeposited);
            assertEq(marketRewards.collateralBalances(_for) - balanceCollateralBefore, lpDeposited);
        } else {
            assertEq(marketRewards.socFeePending(), socFeePending + feeToTake);
            assertEq(marketRewards.totalCollateral() - totalCollateralBefore, lpDeposited - feeToTake);
            assertEq(marketRewards.collateralBalances(_for) - balanceCollateralBefore, lpDeposited - feeToTake);
        }

        assertERC20Tracking();

        vm.stopPrank();
    }

    function _verifyCollatReceived(uint256 lpDeposited, bool isStaked, address receiverStaking) internal {
        IERC20 collatToken = marketRewards.collatToken();

        uint256 socFeePercentage = marketRewards.socFeePercentage();
        uint256 socFeePending = marketRewards.socFeePending();

        if (isStaked) {
            verifyBalERC20NotChanging(collatToken, address(marketRewards), "Collat is not received by market");
            verifyReceiveERC20(marketRewards.cvxRewardToken(), address(marketRewards), lpDeposited, "Collat is received by the staking contract");
        } else {
            uint256 feeToTake = (lpDeposited * socFeePercentage) / 100_000;
            verifyReceiveERC20(collatToken, address(marketRewards), lpDeposited, "Collat is deposited");
        }
    }
}
