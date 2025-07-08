// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";

import "../../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../../handler/Curve/HLPManipulator.sol";
import "../../../../handler/Features/HProcessRewards.sol";
import "../../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
contract SelfLiquidateDirect is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;

    HDepositConvexCrvLP public hDeposit;

    uint256[][] public swapParams;
    address[] public route;

    uint256 public collatDeposited = 5_000 ether;
    uint256 public initialDebt = 4_250 ether;
    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;

        market = deployConvexCurveLPMarket(collatToken, true);

        hDeposit = new HDepositConvexCrvLP(usr1, market);
        hDeposit.depositAndBorrow(collatDeposited, initialDebt);
    }

    function test_selfLiquidate_all_position_with_USG_having_before() external {
        vm.startPrank(usr1);
        uint256 collatToDump = market.collateralBalances(usr1);

        verifyBurnERC20(usg, initialDebt, "usg Burnt after a repay");
        verifyLostERC20(usg, usr1, initialDebt, "usg taken from usr1");

        market.selfLiquidate(collatDeposited, MAX_UINT, initialDebt, ZapStruct({router: address(0), routerCall: ""}));

        assertERC20Tracking();

        assertEq(market.collateralBalances(usr1), 0);
        assertEq(market.totalCollateral(), 0);
        assertEq(market.userDebt(usr1), 0);
        assertEq(market.totalDebt(), 0);

        vm.stopPrank();
    }
}
