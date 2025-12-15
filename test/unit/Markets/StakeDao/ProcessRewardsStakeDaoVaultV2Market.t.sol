// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract ProcessRewardsStakeDaoVaultV2Market is MarketDeploymentContext {
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

        vm.startPrank(usr1);
        vaultToken.approve(address(market), MAX_UINT);
        market.depositAndBorrow(100_000 ether, 80_000 ether, true);
        skip(1 weeks);
    }

    function test_processRewards_StakeDaoVaultV2() external {
        rewardAccumulator.processRewards(address(market), usr1);
    }
}
