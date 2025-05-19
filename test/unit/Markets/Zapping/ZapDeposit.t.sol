// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ZapDeposit is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;

    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken = AddrCurveStableLP.USDC_crvUSD;

    function setUp() public {
        market = deployConvexCurveLPMarket(collatToken, true);
    }

    function test_zap_deposit_with_ERC20() external {
        vm.startPrank(usr1);

        uint256 amountIn = 50_000 ether;
        uint256 amountOut = 10_000 ether;

        deal(address(AddrClassicERC20.CRV), usr1, amountIn);
        deal(address(collatToken), address(mockRouter), amountOut);

        verifyLostERC20(AddrClassicERC20.CRV, usr1, amountIn, "Usr1 lost the CRV");
        verifyReceiveERC20(AddrClassicERC20.CRV, address(mockRouter), amountIn, "MockRouter receives the CRV");

        AddrClassicERC20.CRV.forceApprove(address(market), amountIn);

        // First deposit, stakes on Convex

        market.zapDeposit(
            usr1,
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.CRV,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), AddrClassicERC20.CRV, amountIn, collatToken, address(market), amountOut)
            })
        );

        assertEq(market.cvxRewardToken().balanceOf(address(market)), amountOut, "AmountOut is staked by the market in Convex");
        assertEq(market.collateralBalances(usr1), amountOut, "User collateral is equal to the amountOut");
        assertEq(market.totalCollateral(), amountOut, "Total collateral is equal to the amountOut");

        assertERC20Tracking();
    }

    function test_zap_deposit_with_ETH() external {
        vm.startPrank(usr1);

        uint256 amountIn = 5 ether;
        uint256 amountOut = 10_000 ether;

        deal(usr1, 2 * amountIn);
        deal(usr2, amountIn);

        deal(address(collatToken), address(mockRouter), 3 * amountOut);

        verifyLostERC20(ETH_NAKED, usr1, amountIn, "Usr1 lost the ETH");
        verifyReceiveERC20(ETH_NAKED, address(mockRouter), amountIn, "MockRouter receives the ETH");

        // First deposit, stakes on Convex

        market.zapDeposit{value: amountIn}(
            usr1,
            true,
            ZapStructDeposit({
                tokenIn: ETH_NAKED,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), ETH_NAKED, amountIn, collatToken, address(market), amountOut)
            })
        );

        assertEq(market.cvxRewardToken().balanceOf(address(market)), amountOut, "AmountOut is staked by the market in Convex");
        assertEq(market.collateralBalances(usr1), amountOut, "User collateral is equal to the amountOut");
        assertEq(market.totalCollateral(), amountOut, "Total collateral is equal to the amountOut");

        assertERC20Tracking();

        // Second deposit, without staking the collat token on Convex

        verifyReceiveERC20(collatToken, address(market), amountOut, "Market receives the collat token");

        market.zapDeposit{value: amountIn}(
            usr1,
            false,
            ZapStructDeposit({
                tokenIn: ETH_NAKED,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), ETH_NAKED, amountIn, collatToken, address(market), amountOut)
            })
        );

        uint256 collatAdded = (amountOut * (100_000 - market.socFeePercentage())) / 100_000;
        uint256 fee = amountOut - collatAdded;
        uint256 amountOut_ = amountOut;

        assertEq(market.socFeePending(), fee);
        assertEq(market.cvxRewardToken().balanceOf(address(market)), amountOut_, "AmountOut is staked by the market in Convex");
        assertEq(market.collateralBalances(usr1), amountOut_ + collatAdded, "User collateral is equal to the amountOut + collatAdded");
        assertEq(market.totalCollateral(), amountOut_ + collatAdded, "Total collateral is equal to the amountOut + collatAdded");

        assertERC20Tracking();

        // Last deposit, with staking the collat token on Convex to get the fee

        vm.stopPrank();
        vm.startPrank(usr2);

        verifyLostERC20(collatToken, address(market), amountOut_, "Market receives the collat token");

        market.zapDeposit{value: amountIn}(
            usr2,
            true,
            ZapStructDeposit({
                tokenIn: ETH_NAKED,
                amountIn: amountIn,
                minAmountOut: amountOut_,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), ETH_NAKED, amountIn, collatToken, address(market), amountOut_)
            })
        );

        assertEq(market.socFeePending(), 0);
        assertEq(market.cvxRewardToken().balanceOf(address(market)), 3 * amountOut_, "AmountOut is staked by the market in Convex");
        assertEq(market.collateralBalances(usr1), amountOut_ + collatAdded, "User collateral is equal to the amountOut + collatAdded");
        assertEq(market.collateralBalances(usr2), amountOut_ + (amountOut_ - collatAdded), "1 amountOut + fee that are pending");
        assertEq(market.totalCollateral(), 3 * amountOut_, "Total collateral is equal to the amountOut + collatAdded");

        assertERC20Tracking();
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
            AddrClassicERC20.CVX,
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
