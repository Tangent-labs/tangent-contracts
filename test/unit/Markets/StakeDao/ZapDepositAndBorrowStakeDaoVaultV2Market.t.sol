// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract ZapDepositAndBorrowStakeDaoVaultV2Market is MarketDeploymentContext {
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

    function test_zapDepositAndBorrow_and_withdraw_with_lp_token() external {
        vm.startPrank(usr1);
        uint256 amountInZap = 100_000 * 10 ** 6;
        uint256 amountOut = 12_000 ether;

        uint256 borrowedAmount = 5_000 ether;

        deal(address(AddrClassicERC20.USDT), usr1, amountInZap);
        deal(address(collatToken), address(zappingProxy), amountOut);

        AddrClassicERC20.USDT.forceApprove(address(market), MAX_UINT);

        verifyLostERC20(AddrClassicERC20.USDT, usr1, amountInZap, "USDT transferred from user to zappingProxy");
        verifyReceiveERC20(vaultToken, address(market), amountOut, "Vault received by market");

        market.zapDepositAndBorrow(
            borrowedAmount,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountInZap,
                minAmountOut: amountOut,
                zap: ZapStruct({router: address(collatToken), routerCall: abi.encodeWithSelector(IERC20.transfer.selector, address(market), amountOut)})
            })
        );

        assertERC20Tracking();

        skip(1 weeks);

        rewardAccumulator.processRewards(address(market), usr1);

        skip(1 weeks);

        rewardAccumulator.claimSimple(address(market));

        market.repayAndWithdraw(amountOut, borrowedAmount, false);
    }
}
