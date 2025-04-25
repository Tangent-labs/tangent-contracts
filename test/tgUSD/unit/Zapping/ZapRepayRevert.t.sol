// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../src/tgUSD/Utilities/Zapper.sol";
import "../../contexts/MarketDeploymentContext.sol";
import "../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";

contract ZapRepayRevert is MarketDeploymentContext {
    ConvexCrvLPMarket public market;
    IERC20Metadata public collatToken;
    HDepositConvexCrvLP public hDeposit;

    uint256 initialDeposit = 10_000 ether;
    uint256 initialDebt = 6_000 ether;

    IERC20 constant ETH_NAKED = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    function setUp() public {
        collatToken = AddrCurveStableLP.USDC_crvUSD;
        market = deployConvexCurveLPMarket(collatToken);
        hDeposit = new HDepositConvexCrvLP(usr1, market);

        hDeposit.depositAndBorrow(initialDeposit, initialDebt, true, usr1);
    }

    //TODO remove this comment when the test is ready
    // function test_zap_repay_slippage_error() external {
    //     uint256 amountIn = 0.1 ether;
    //     uint256 minAmountOut = 100;

    //     vm.mockFunction(address(AddrRouter.ENSO_ROUTER_V2), address(mockEnsoRouter), abi.encodeWithSelector(IEnsoRouterV2.routeSingle.selector));

    //     vm.startPrank(usr1);
    //     deal(usr1, amountIn);

    //     bytes32[] memory commands = Array.memoryBytes32(
    //         [addressToBytes32(address(tgUSD)), addressToBytes32(mockedLP), addressToBytes32(usr1), addressToBytes32(address(zapper)), bytes32(minAmountOut - 1)]
    //     );
    //     bytes[] memory state = new bytes[](0);
    //     vm.expectRevert(abi.encodeWithSelector(Zapper.MinAmountOutNotReached.selector));
    //     zapper.zapRepay{value: amountIn}(
    //         Zapper.ZapMarket({market: address(market), tokenIn: ETH_NAKED, amountIn: amountIn, minAmountOut: minAmountOut, _for: usr1}),
    //         abi.encodeWithSelector(IEnsoRouterV2.routeSingle.selector, address(ETH_NAKED), amountIn, commands, state)
    //     );
    // }

    function test_zap_repay_with_msg_value_but_tokenIn_not_eth() external {
        uint256 amountIn = 0.1 ether;

        vm.mockFunction(address(AddrRouter.ENSO_ROUTER_V2), address(mockEnsoRouter), abi.encodeWithSelector(IEnsoRouterV2.routeSingle.selector));

        vm.startPrank(usr1);
        deal(usr1, amountIn);

        bytes32[] memory commands = Array.memoryBytes32(
            [addressToBytes32(address(tgUSD)), addressToBytes32(mockedLP), addressToBytes32(usr1), addressToBytes32(address(zapper)), bytes32(0)]
        );
        bytes[] memory state = new bytes[](0);
        vm.expectRevert(abi.encodeWithSelector(Zapper.TokenInMustBeZero.selector));
        zapper.zapRepay{value: amountIn}(
            Zapper.ZapMarket({market: address(market), tokenIn: AddrClassicERC20.USDC, amountIn: amountIn, minAmountOut: 0, _for: usr1}),
            abi.encodeWithSelector(IEnsoRouterV2.routeSingle.selector, address(ETH_NAKED), amountIn, commands, state)
        );
    }

    function test_zap_repay_with_eth_but_no_msg_value() external {
        uint256 amountIn = 0.1 ether;

        vm.startPrank(usr1);
        deal(usr1, amountIn);

        bytes32[] memory commands = Array.memoryBytes32(
            [addressToBytes32(address(tgUSD)), addressToBytes32(mockedLP), addressToBytes32(usr1), addressToBytes32(address(zapper)), bytes32(0)]
        );
        bytes[] memory state = new bytes[](0);
        vm.expectRevert(abi.encodeWithSelector(Zapper.TokenInMustNotBeZero.selector));
        zapper.zapRepay(
            Zapper.ZapMarket({market: address(market), tokenIn: ETH_NAKED, amountIn: amountIn, minAmountOut: 0, _for: usr1}),
            abi.encodeWithSelector(IEnsoRouterV2.routeSingle.selector, address(ETH_NAKED), amountIn, commands, state)
        );
    }

    function test_zap_repay_on_a_contract_that_is_not_a_market() external {
        uint256 amountIn = 0.1 ether;

        vm.startPrank(usr1);
        deal(usr1, amountIn);

        bytes32[] memory commands = Array.memoryBytes32(
            [addressToBytes32(address(tgUSD)), addressToBytes32(mockedLP), addressToBytes32(usr1), addressToBytes32(address(zapper)), bytes32(0)]
        );
        bytes[] memory state = new bytes[](0);
        vm.expectRevert(abi.encodeWithSelector(Zapper.NotMarket.selector, address(AddrClassicERC20.USDC)));
        zapper.zapRepay(
            Zapper.ZapMarket({market: address(AddrClassicERC20.USDC), tokenIn: ETH_NAKED, amountIn: amountIn, minAmountOut: 0, _for: usr1}),
            abi.encodeWithSelector(IEnsoRouterV2.routeSingle.selector, address(ETH_NAKED), amountIn, commands, state)
        );
    }
}
