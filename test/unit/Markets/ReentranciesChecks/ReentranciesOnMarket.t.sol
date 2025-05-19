// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ReentranciesOnMarket is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;

    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken = AddrCurveStableLP.USDC_crvUSD;

    uint256 amountIn = 50_000 ether;
    uint256 amountOut = 50_000 ether;

    bytes ZapCallErrorReentrancy;

    function setUp() public {
        market = deployConvexCurveLPMarket(collatToken, true);

        ZapCallErrorReentrancy = abi.encodeWithSelector(ZappingProxy.ZapCallError.selector, abi.encodeWithSelector(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector));

        vm.startPrank(usr1);
        deal(address(AddrClassicERC20.CRV), usr1, amountIn);
        AddrClassicERC20.CRV.forceApprove(address(market), amountIn);
    }

    function test_reentrancy_deposit() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        market.zapDeposit(
            usr1,
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.CRV,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: ZapStruct({router: address(market), routerCall: abi.encodeWithSelector(MarketExternalActions.deposit.selector, usr1, amountIn, true)})
            })
        );
    }

    function test_reentrancy_zapDeposit() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        market.zapDeposit(
            usr1,
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.CRV,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: ZapStruct({
                    router: address(market),
                    routerCall: abi.encodeWithSelector(
                        MarketExternalActions.zapDeposit.selector,
                        usr1,
                        true,
                        ZapStructDeposit({tokenIn: AddrClassicERC20.CRV, amountIn: amountIn, minAmountOut: amountOut, zap: ZapStruct({router: address(0), routerCall: ""})})
                    )
                })
            })
        );
    }

    function test_reentrancy_depositAndBorrow() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        market.zapDeposit(
            usr1,
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.CRV,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: ZapStruct({router: address(market), routerCall: abi.encodeWithSelector(MarketExternalActions.depositAndBorrow.selector, amountIn, amountIn, true)})
            })
        );
    }

    function test_reentrancy_zapDepositAndBorrow() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        market.zapDeposit(
            usr1,
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.CRV,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: ZapStruct({
                    router: address(market),
                    routerCall: abi.encodeWithSelector(
                        MarketExternalActions.zapDepositAndBorrow.selector,
                        amountIn,
                        true,
                        ZapStructDeposit({tokenIn: AddrClassicERC20.CRV, amountIn: amountIn, minAmountOut: amountOut, zap: ZapStruct({router: address(0), routerCall: ""})})
                    )
                })
            })
        );
    }

    function test_reentrancy_withdraw() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        market.zapDeposit(
            usr1,
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.CRV,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: ZapStruct({router: address(market), routerCall: abi.encodeWithSelector(MarketExternalActions.withdraw.selector, amountIn)})
            })
        );
    }

    function test_reentrancy_repayAndWithdraw() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        market.zapDeposit(
            usr1,
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.CRV,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: ZapStruct({router: address(market), routerCall: abi.encodeWithSelector(MarketExternalActions.repayAndWithdraw.selector, amountIn, amountIn)})
            })
        );
    }

    function test_reentrancy_zapRepayAndWithdraw() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        market.zapDeposit(
            usr1,
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.CRV,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: ZapStruct({
                    router: address(market),
                    routerCall: abi.encodeWithSelector(
                        MarketExternalActions.zapRepayAndWithdraw.selector,
                        amountIn,
                        ZapStructDeposit({tokenIn: AddrClassicERC20.CRV, amountIn: amountIn, minAmountOut: amountOut, zap: ZapStruct({router: address(market), routerCall: ""})})
                    )
                })
            })
        );
    }

    function test_reentrancy_borrow() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        market.zapDeposit(
            usr1,
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.CRV,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: ZapStruct({router: address(market), routerCall: abi.encodeWithSelector(MarketExternalActions.borrow.selector, usr1, amountIn)})
            })
        );
    }

    function test_reentrancy_repay() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        market.zapDeposit(
            usr1,
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.CRV,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: ZapStruct({router: address(market), routerCall: abi.encodeWithSelector(MarketExternalActions.repay.selector, usr1, amountIn)})
            })
        );
    }

    function test_reentrancy_zapRepay() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        market.zapDeposit(
            usr1,
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.CRV,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: ZapStruct({
                    router: address(market),
                    routerCall: abi.encodeWithSelector(
                        MarketExternalActions.zapRepay.selector,
                        usr1,
                        ZapStructDeposit({tokenIn: AddrClassicERC20.CRV, amountIn: amountIn, minAmountOut: amountOut, zap: ZapStruct({router: address(market), routerCall: ""})})
                    )
                })
            })
        );
    }

    function test_reentrancy_liquidate() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        market.zapDeposit(
            usr1,
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.CRV,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: ZapStruct({
                    router: address(market),
                    routerCall: abi.encodeWithSelector(MarketExternalActions.liquidate.selector, usr1, amountIn, amountIn, ZapStruct({router: address(market), routerCall: ""}))
                })
            })
        );
    }

    function test_reentrancy_selfLiquidate() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        market.zapDeposit(
            usr1,
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.CRV,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: ZapStruct({
                    router: address(market),
                    routerCall: abi.encodeWithSelector(
                        MarketExternalActions.selfLiquidate.selector,
                        amountIn,
                        amountIn,
                        amountIn,
                        ZapStruct({router: address(market), routerCall: ""})
                    )
                })
            })
        );
    }

    function test_reentrancy_liquidateBadDebt() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        market.zapDeposit(
            usr1,
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.CRV,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: ZapStruct({router: address(market), routerCall: abi.encodeWithSelector(MarketExternalActions.liquidateBadDebt.selector, usr1)})
            })
        );
    }

    function test_reentrancy_leverage() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        market.zapDeposit(
            usr1,
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.CRV,
                amountIn: amountIn,
                minAmountOut: amountOut,
                zap: ZapStruct({
                    router: address(market),
                    routerCall: abi.encodeWithSelector(
                        MarketExternalActions.leverage.selector,
                        amountIn,
                        amountIn,
                        amountIn,
                        true,
                        ZapStruct({router: address(market), routerCall: ""})
                    )
                })
            })
        );
    }
}
