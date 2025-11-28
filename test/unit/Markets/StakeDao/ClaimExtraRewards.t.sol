// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract ClaimExtraRewards is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;

    StakeDaoVaultV2Market public market;
    IStakeDaoVaultV2 public vaultToken;
    IERC20Metadata public collatToken;

    uint256 minimumLoan;
    function setUp() public {
        vaultToken = AddrStakeDaoVaultV2.USDC_crvUSD_LP;
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployStakeDaoVaultV2Market(collatToken);
        minimumLoan = market.minimumLoan();
    }

    function test_claimExtraRewards() external {
        vm.startPrank(usr1);
        uint256 amountIn = 10_000 ether;
        uint256 borrowedAmount = 5_000 ether;

        vaultToken.approve(address(market), MAX_UINT);

        //  Verify that gauge token are transfered from user to market directly

        verifyLostERC20(vaultToken, usr1, amountIn, "Gauge transfered from User 1");
        verifyReceiveERC20(vaultToken, address(market), amountIn, "Gauge received by Market");

        market.depositAndBorrow(amountIn, borrowedAmount, true);

        assertERC20Tracking();

        skip(1 weeks);
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = AddrClassicERC20.CVX;

        market.claimExtraRewards(tokens);

        assertERC20Tracking();
    }
}
