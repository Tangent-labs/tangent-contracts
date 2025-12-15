// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract DepositStakeDaoVaultV2Market is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;

    StakeDaoVaultV2Market public market;
    IStakeDaoVaultV2 public vaultToken;
    IERC20Metadata public collatToken;
    uint256 amountIn = 10_000 ether;

    function setUp() public {
        vaultToken = AddrStakeDaoVaultV2.USDC_crvUSD_LP;
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployStakeDaoVaultV2Market(collatToken);
    }

    function test_deposit_with_lp_and_repayWithdraw_with_vault_token() external {
        vm.startPrank(usr1);

        collatToken.approve(address(market), MAX_UINT);

        //  Verify that gauge token are transfered from user to market directly

        verifyLostERC20(collatToken, usr1, amountIn, "Gauge transfered from User 1");
        verifyReceiveERC20(vaultToken, address(market), amountIn, "Gauge received by Market");

        market.deposit(usr2, amountIn, false);

        assertERC20Tracking();

        skip(1 weeks);

        rewardAccumulator.processRewards(address(market), usr1);
        vm.stopPrank();
        vm.startPrank(usr2);

        skip(1 weeks);
        //  Verify that gauge token are unwrapped to LP and sent to user
        verifyLostERC20(vaultToken, address(market), amountIn, "Gauge transfered from Market");
        verifyReceiveERC20(vaultToken, usr2, amountIn, "LP received by User 1");

        market.withdraw(amountIn, true);

        rewardAccumulator.claimSimple(address(market));

        assertERC20Tracking();
    }

    function test_deposit_with_vault_and_repayWithdraw_with_lp_token() external {
        vm.startPrank(usr1);

        vaultToken.approve(address(market), MAX_UINT);

        //  Verify that gauge token are transfered from user to market directly
        verifyLostERC20(vaultToken, usr1, amountIn, "Gauge transfered from User 1");
        verifyReceiveERC20(vaultToken, address(market), amountIn, "Gauge received by Market");

        market.deposit(usr2, amountIn, true);

        assertERC20Tracking();

        skip(1 weeks);

        rewardAccumulator.processRewards(address(market), usr1);

        skip(1 weeks);

        vm.stopPrank();
        vm.startPrank(usr2);

        //  Verify that gauge token are unwrapped to LP and sent to user
        verifyLostERC20(vaultToken, address(market), amountIn, "Gauge transfered from Market");
        verifyBurnERC20(vaultToken, amountIn, "Gauge Burnt");
        verifyReceiveERC20(collatToken, usr2, amountIn, "LP received by User 1");

        market.withdraw(amountIn, false);

        rewardAccumulator.claimSimple(address(market));

        assertERC20Tracking();
    }
}
