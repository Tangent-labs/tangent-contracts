// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract DepositBasicERC20Market is MarketDeploymentContext {
    BasicERC20Market public market;
    IERC20Metadata public collatToken;

    uint256 collatDeposited1 = 5_000 ether;
    uint256 borrowedAmount1 = 3_440 ether;
    function setUp() public {
        collatToken = AddrPTPendle.eUSDe_29_05_25;
        market = deployBasicERC20Market(collatToken);
        deal(address(collatToken), usr1, collatDeposited1);

        vm.prank(usr1);
        collatToken.approve(address(market), MAX_UINT);
    }

    //
    function test_deposit_and_borrow_stake_have_no_impact() external {
        vm.startPrank(usr1);

        verifyLostERC20(collatToken, usr1, collatDeposited1);
        verifyReceiveERC20(collatToken, address(market), collatDeposited1);

        market.depositAndBorrow(collatDeposited1, borrowedAmount1);

        assertERC20Tracking();
    }

    function test_deposit_and_borrow_without_stake_then_withdraw_has_no_impact_on_staked_amount() external {
        vm.startPrank(usr1);

        // Deposit
        verifyLostERC20(collatToken, usr1, collatDeposited1);
        verifyReceiveERC20(collatToken, address(market), collatDeposited1);

        market.depositAndBorrow(collatDeposited1, borrowedAmount1);

        assertERC20Tracking();

        // Withdraw
        verifyLostERC20(collatToken, address(market), collatDeposited1);
        verifyReceiveERC20(collatToken, usr1, collatDeposited1);

        market.repayAndWithdraw(collatDeposited1, borrowedAmount1);

        assertERC20Tracking();
    }

    function test_deposit_fails_with_0() external {
        vm.startPrank(usr1);

        vm.expectRevert(abi.encodeWithSelector(MarketCore.ZeroCollatAmount.selector));
        market.deposit(usr1, 0);
    }
}
