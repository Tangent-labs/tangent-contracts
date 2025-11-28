// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract ZapIncreaseLockAmount is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;

    uint208 amountIn = 10_000 ether;
    uint208 amountOutTan = 1_000 ether;

    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 2 * amountIn);
        tan.approve(address(vsTan), 2 * amountIn);
        // 1 is permalocked
        vsTan.createLock(amountIn, true);
        // 2 is not permalocked
        vsTan.createLock(amountIn, false);
        vm.stopPrank();
    }

    function test_zapCreateLock_with_ETH() external {
        vm.startPrank(usr1);

        deal(usr1, amountIn);
        deal(address(tan), address(mockRouter), amountOutTan);

        verifyLostERC20(ETH_NAKED, usr1, amountIn, "ETH is sent by user");
        verifyReceiveERC20(ETH_NAKED, address(mockRouter), amountIn, "Router received ETH");

        verifyReceiveERC20(tan, address(vsTan), amountOutTan, "TAN receives by VsTAN");

        vsTan.zapIncreaseLockAmount{value: amountIn}(
            1,
            ZapStructDeposit({
                tokenIn: ETH_NAKED,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), ETH_NAKED, amountIn, tan, address(vsTan), amountOutTan)
            })
        );

        assertERC20Tracking();

        Lock memory lock = vsTan.getLock(1);
        assertEq(lock.amount, amountOutTan + amountIn);
        assertEq(lock.endLockTime, vsTan.MAX_UINT48());
    }

    function test_zapCreateLock_with_ERC20() external {
        vm.startPrank(usr1);

        deal(address(AddrClassicERC20.USDT), usr1, amountIn);
        deal(address(tan), address(mockRouter), amountOutTan);

        AddrClassicERC20.USDT.forceApprove(address(vsTan), MAX_UINT);

        verifyLostERC20(AddrClassicERC20.USDT, usr1, amountIn, "USDT is sent by user");
        verifyReceiveERC20(AddrClassicERC20.USDT, address(mockRouter), amountIn, "Router received USDT");

        verifyReceiveERC20(tan, address(vsTan), amountOutTan, "TAN receives by VsTAN");

        vsTan.zapIncreaseLockAmount(
            1,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), AddrClassicERC20.USDT, amountIn, tan, address(vsTan), amountOutTan)
            })
        );

        assertERC20Tracking();

        Lock memory lock = vsTan.getLock(1);
        assertEq(lock.amount, amountOutTan + amountIn);
        assertEq(lock.endLockTime, vsTan.MAX_UINT48());
    }
}
