// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ReentranciesOnRsTan is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;

    uint256 amountIn = 10 ether;

    bytes ZapCallErrorReentrancy;

    function setUp() public {
        vm.startPrank(usr1);
        ZapCallErrorReentrancy = abi.encodeWithSelector(ZappingProxy.ZapCallError.selector, abi.encodeWithSelector(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector));

        deal(address(AddrClassicERC20.USDT), usr1, amountIn);
        AddrClassicERC20.USDT.forceApprove(address(rsTan), MAX_UINT);
    }

    function test_reentrancy_createLock() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        rsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(rsTan), routerCall: abi.encodeWithSelector(RsTan.createLock.selector, amountIn, true)})
            })
        );
    }

    function test_reentrancy_zapCreateLock() external {
        vm.expectRevert(ZapCallErrorReentrancy);
        rsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({
                    router: address(rsTan),
                    routerCall: abi.encodeWithSelector(
                        RsTan.zapCreateLock.selector,
                        true,
                        ZapStructDeposit({tokenIn: AddrClassicERC20.USDT, amountIn: amountIn, minAmountOut: 0, zap: ZapStruct({router: address(rsTan), routerCall: ""})})
                    )
                })
            })
        );
    }

    function test_reentrancy_increaseLockAmount() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        rsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(rsTan), routerCall: abi.encodeWithSelector(RsTan.increaseLockAmount.selector, 1, amountIn)})
            })
        );
    }

    function test_reentrancy_zapIncreaseLockAmount() external {
        vm.expectRevert(ZapCallErrorReentrancy);
        rsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({
                    router: address(rsTan),
                    routerCall: abi.encodeWithSelector(
                        RsTan.zapIncreaseLockAmount.selector,
                        1,
                        ZapStructDeposit({tokenIn: AddrClassicERC20.USDT, amountIn: amountIn, minAmountOut: 0, zap: ZapStruct({router: address(rsTan), routerCall: ""})})
                    )
                })
            })
        );
    }

    function test_reentrancy_increaseLockTime() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        rsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(rsTan), routerCall: abi.encodeWithSelector(RsTan.increaseLockTime.selector, 1)})
            })
        );
    }

    function test_reentrancy_togglePermaLock() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        rsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(rsTan), routerCall: abi.encodeWithSelector(RsTan.togglePermaLock.selector, 1)})
            })
        );
    }

    function test_reentrancy_unlock() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        rsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(rsTan), routerCall: abi.encodeWithSelector(RsTan.unlock.selector, 1, false)})
            })
        );
    }

    function test_reentrancy_rageQuit() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        rsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(rsTan), routerCall: abi.encodeWithSelector(RsTan.rageQuit.selector, 1, false)})
            })
        );
    }

    function test_reentrancy_kickPosition() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        rsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(rsTan), routerCall: abi.encodeWithSelector(RsTan.kickPosition.selector, 1, usr1)})
            })
        );
    }

    function test_reentrancy_split() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        rsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(rsTan), routerCall: abi.encodeWithSelector(RsTan.split.selector, 1, 100 ether)})
            })
        );
    }

    function test_reentrancy_merge() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        rsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(rsTan), routerCall: abi.encodeWithSelector(RsTan.merge.selector, 1, 2, true)})
            })
        );
    }

    function test_reentrancy_claimSimple() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        rsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(rsTan), routerCall: abi.encodeWithSelector(RsTan.claimSimple.selector, 1, true)})
            })
        );
    }

    function test_reentrancy_claimMultiple() external {
        uint256[] memory tokens = Array.memoryUint256([uint256(1)]);
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        rsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(rsTan), routerCall: abi.encodeWithSelector(RsTan.claimMultiple.selector, tokens, true)})
            })
        );
    }
}
