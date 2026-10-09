// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract VolatileCvxEthStakeDaoMarket is MarketDeploymentContext {
    StakeDaoVaultV2Market public market;
    IStakeDaoVaultV2 public vaultToken;
    IERC20Metadata public collatToken;

    function setUp() public {
        vaultToken = AddrStakeDaoVaultV2.CVX_ETH_LP;
        collatToken = AddrCryptoSwapLP.CVX_ETH_LP;
        market = deployStakeDaoVaultV2Market(collatToken);
    }

    function test_deploy() external view {
        assertEq(address(market.receiptToken()), address(vaultToken));
        assertGt(market.collatOracle().latestAnswer(false), 0);
        assertTrue(usg.isMinter(address(market)));
        assertTrue(usg.isBurner(address(market)));
    }

    function test_depositBorrow_vault_then_repayWithdraw_lp() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        uint256 borrowedAmount = 5_000 ether;

        vaultToken.approve(address(market), MAX_UINT);

        verifyLostERC20(vaultToken, usr1, amountIn, "Vault transfered from User 1");
        verifyReceiveERC20(vaultToken, address(market), amountIn, "Vault received by Market");

        market.depositAndBorrow(amountIn, borrowedAmount, true);

        assertERC20Tracking();

        skip(1 weeks);
        rewardAccumulator.processRewards(address(market), usr1);
        skip(1 weeks);

        verifyLostERC20(vaultToken, address(market), amountIn, "Vault transfered from Market");
        verifyBurnERC20(vaultToken, amountIn, "Vault Burnt");
        verifyReceiveERC20(collatToken, usr1, amountIn, "LP received by User 1");

        market.repayAndWithdraw(amountIn, borrowedAmount, false);

        rewardAccumulator.claimSimple(address(market));

        assertERC20Tracking();
    }

    function test_depositBorrow_lp() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        uint256 borrowedAmount = 5_000 ether;

        collatToken.approve(address(market), MAX_UINT);

        verifyLostERC20(collatToken, usr1, amountIn, "LP transfered from User 1");
        verifyReceiveERC20(vaultToken, address(market), amountIn, "Vault received by Market");

        market.depositAndBorrow(amountIn, borrowedAmount, false);

        assertERC20Tracking();
        assertEq(market.collateralBalances(usr1), amountIn);
    }
}
