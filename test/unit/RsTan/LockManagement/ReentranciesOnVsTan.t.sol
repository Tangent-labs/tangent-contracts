// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract ReentranciesOnVsTan is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;

    uint256 amountIn = 10 ether;

    bytes ZapCallErrorReentrancy;

    function setUp() public {
        vm.startPrank(usr1);
        ZapCallErrorReentrancy = abi.encodeWithSelector(
            ZappingProxy.ZapCallError.selector,
            abi.encodeWithSelector(LightReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector)
        );

        deal(address(AddrClassicERC20.USDT), usr1, amountIn);
        AddrClassicERC20.USDT.forceApprove(address(vsTan), MAX_UINT);
    }

    function test_reentrancy_createLock() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.createLock.selector, amountIn, true)})
            })
        );
    }

    function test_reentrancy_zapCreateLock() external {
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({
                    router: address(vsTan),
                    routerCall: abi.encodeWithSelector(
                        VsTAN.zapCreateLock.selector,
                        true,
                        ZapStructDeposit({tokenIn: AddrClassicERC20.USDT, amountIn: amountIn, minAmountOut: 0, zap: ZapStruct({router: address(vsTan), routerCall: ""})})
                    )
                })
            })
        );
    }

    function test_reentrancy_increaseLockAmount() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.increaseLockAmount.selector, 1, amountIn)})
            })
        );
    }

    function test_reentrancy_zapIncreaseLockAmount() external {
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({
                    router: address(vsTan),
                    routerCall: abi.encodeWithSelector(
                        VsTAN.zapIncreaseLockAmount.selector,
                        1,
                        ZapStructDeposit({tokenIn: AddrClassicERC20.USDT, amountIn: amountIn, minAmountOut: 0, zap: ZapStruct({router: address(vsTan), routerCall: ""})})
                    )
                })
            })
        );
    }

    function test_reentrancy_increaseLockTime() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.increaseLockTime.selector, 1)})
            })
        );
    }

    function test_reentrancy_togglePermaLock() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.togglePermaLock.selector, 1)})
            })
        );
    }

    function test_reentrancy_unlock() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.unlock.selector, 1, false)})
            })
        );
    }

    function test_reentrancy_rageQuit() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.rageQuit.selector, 1, false)})
            })
        );
    }

    function test_reentrancy_kickPosition() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.kickPosition.selector, 1, usr1)})
            })
        );
    }

    function test_reentrancy_split() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.split.selector, 1, 100 ether)})
            })
        );
    }

    function test_reentrancy_merge() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.merge.selector, 1, 2, true)})
            })
        );
    }

    function test_reentrancy_claimSimple() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.claimSimple.selector, 1, true)})
            })
        );
    }

    function test_reentrancy_claimMultiple() external {
        uint256[] memory tokens = Array.memoryUint256([uint256(1)]);
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.claimMultiple.selector, tokens, true)})
            })
        );
    }

    function test_reentrancy_getRewardData() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.getRewardData.selector, usg)})
            })
        );
    }

    function test_reentrancy_lastTimeRewardApplicable() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.lastTimeRewardApplicable.selector, usg)})
            })
        );
    }

    function test_reentrancy_rewardPerToken() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.rewardPerToken.selector, usg)})
            })
        );
    }

    function test_reentrancy_nextEndLockTime() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.nextEndLockTime.selector)})
            })
        );
    }

    function test_reentrancy_getLock() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.getLock.selector, 1)})
            })
        );
    }

    function test_reentrancy_claimableRewards() external {
        // Verify that the call to the "router" returns an error about the reentrancy
        vm.expectRevert(ZapCallErrorReentrancy);
        vsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: ZapStruct({router: address(vsTan), routerCall: abi.encodeWithSelector(VsTAN.claimableRewards.selector, 1)})
            })
        );
    }
}
