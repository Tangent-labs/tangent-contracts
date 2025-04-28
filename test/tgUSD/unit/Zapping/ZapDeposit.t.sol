// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract ZapDeposit is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken = AddrCurveStableLP.USDC_crvUSD;

    IERC20 constant ETH_NAKED = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    function setUp() public {
        market = deployConvexCurveLPMarket(collatToken);
    }

    // Ensure that user cannot call deposit inside zap and deposit
    // Indeed, deposit satisfies the conditions to have more collatToken on the market between before and after the call to the "router".
    // If the reantrancy guard wasn't setup, malicious actors could double their collateralBalances and empty all collaterals
    function test_zap_deposit_reeantrancy_with_deposit() external {
        vm.startPrank(usr1);

        deal(address(AddrClassicERC20.CVX), usr1, 100 ether);
        deal(address(collatToken), address(zappingProxy), 1_000 ether);

        AddrClassicERC20.CVX.approve(address(market), MAX_UINT);

        // Make the zapping proxy allow collat token to be spent by the market
        zappingProxy.zapProxy(
            collatToken,
            collatToken,
            0,
            usr1,
            ZapStruct({router: address(collatToken), routerCall: abi.encodeWithSelector(bytes4(keccak256("approve(address,uint256)")), address(market), MAX_UINT)})
        );

        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(abi.encodeWithSelector(ZappingProxy.ZapCallError.selector, abi.encodeWithSelector(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector)));

        market.zapDeposit(
            usr1,
            false,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.CVX,
                amountIn: 1,
                minAmountOut: 0,
                zap: ZapStruct({router: address(market), routerCall: abi.encodeWithSelector(bytes4(keccak256("deposit(address,uint256,bool)")), usr1, 1_000 ether, false)})
            })
        );
    }
}
