// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract ZapCreateLock is MarketDeploymentContext {
    using SafeERC20 for IERC20Metadata;

    uint208 amountIn = 1 ether;
    uint208 amountOutTan = 1_000 ether;

    function setUp() external {
        vm.startPrank(usr1);
        deal(address(tan), usr1, 2 * amountIn);
        tan.approve(address(rsTan), 2 * amountIn);
        // 1 is permalocked
        rsTan.createLock(amountIn, true);
        // 2 is not permalocked
        rsTan.createLock(amountIn, false);
        vm.stopPrank();
    }

    function test_zapCreateLock_with_ETH() external {
        vm.startPrank(usr1);

        deal(usr1, amountIn);
        deal(address(tan), address(mockRouter), amountOutTan);

        verifyLostERC20(ETH_NAKED, usr1, amountIn, "ETH is sent by user");
        verifyReceiveERC20(ETH_NAKED, address(mockRouter), amountIn, "Router received ETH");

        verifyReceiveERC20(tan, address(rsTan), amountOutTan, "Tan receives by RsTan");

        rsTan.zapCreateLock{value: amountIn}(
            true,
            ZapStructDeposit({
                tokenIn: ETH_NAKED,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), ETH_NAKED, amountIn, tan, address(rsTan), amountOutTan)
            })
        );

        assertERC20Tracking();

        Lock memory lock = rsTan.getLock(3);
        assertEq(lock.amount, amountOutTan);
        assertEq(lock.endLockTime, rsTan.MAX_UINT48());
    }

    function test_zapCreateLock_with_ERC20() external {
        vm.startPrank(usr1);

        deal(address(AddrClassicERC20.USDT), usr1, amountIn);
        deal(address(tan), address(mockRouter), amountOutTan);

        AddrClassicERC20.USDT.forceApprove(address(rsTan), MAX_UINT);

        verifyLostERC20(AddrClassicERC20.USDT, usr1, amountIn, "USDT is sent by user");
        verifyReceiveERC20(AddrClassicERC20.USDT, address(mockRouter), amountIn, "Router received USDT");

        verifyReceiveERC20(tan, address(rsTan), amountOutTan, "Tan receives by RsTan");

        rsTan.zapCreateLock(
            true,
            ZapStructDeposit({
                tokenIn: AddrClassicERC20.USDT,
                amountIn: amountIn,
                minAmountOut: 0,
                zap: encoder.encodeSwapToMockRouter(address(mockRouter), AddrClassicERC20.USDT, amountIn, tan, address(rsTan), amountOutTan)
            })
        );

        assertERC20Tracking();

        Lock memory lock = rsTan.getLock(3);
        assertEq(lock.amount, amountOutTan);
        assertEq(lock.endLockTime, rsTan.MAX_UINT48());
    }

    function test_zapCreateLock_fails_with_0_in_amountIn() external {
        vm.startPrank(usr1);

        ZapStruct memory zapCall = encoder.encodeSwapToMockRouter(address(mockRouter), AddrClassicERC20.USDT, amountIn, tan, address(rsTan), amountOutTan);

        vm.expectRevert(abi.encodeWithSelector(ZappingUtil.InvalidZapValue.selector));
        rsTan.zapCreateLock(true, ZapStructDeposit({tokenIn: AddrClassicERC20.USDT, amountIn: 0, minAmountOut: 0, zap: zapCall}));
    }

    function test_zapCreateLock_fails_with_msgValue_0_and_ethIN() external {
        vm.startPrank(usr1);

        deal(usr1, 10 ether);

        ZapStruct memory zapCall = encoder.encodeSwapToMockRouter(address(mockRouter), ETH_NAKED, amountIn, tan, address(rsTan), amountOutTan);

        vm.expectRevert(abi.encodeWithSelector(ZappingUtil.InvalidZapValue.selector));
        rsTan.zapCreateLock{value: 0}(true, ZapStructDeposit({tokenIn: ETH_NAKED, amountIn: 10 ether, minAmountOut: 0, zap: zapCall}));
    }

    function test_zapCreateLock_fails_with_msgValue_noEq_amountIn_for_ETH() external {
        vm.startPrank(usr1);

        deal(usr1, 10 ether);

        ZapStruct memory zapCall = encoder.encodeSwapToMockRouter(address(mockRouter), ETH_NAKED, amountIn, tan, address(rsTan), amountOutTan);

        vm.expectRevert(abi.encodeWithSelector(ZappingUtil.InvalidZapValue.selector));
        rsTan.zapCreateLock{value: 9 ether}(true, ZapStructDeposit({tokenIn: ETH_NAKED, amountIn: 10 ether, minAmountOut: 0, zap: zapCall}));
    }
}
