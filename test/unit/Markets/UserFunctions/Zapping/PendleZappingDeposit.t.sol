// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";

contract PendleZappingDeposit is MarketDeploymentContext {
    BasicERC20Market public market;
    IERC20Metadata public collatToken = AddrPTPendle.USDe_27_11_25;
    IERC20 usdc = AddrClassicERC20.USDC;
    function setUp() public {
        market = deployBasicERC20Market(collatToken);
        vm.startPrank(usr1);
        deal(address(usdc), usr1, 10 ether);
        usdc.approve(address(market), MAX_UINT);
    }

    function test_zapDeposit_to_PT() external {
        vm.startPrank(usr1);

        uint256[][] memory swapParams = new uint256[][](4);
        swapParams[0] = Array.memoryUint256([uint256(1), uint256(0), uint256(1), uint256(1), uint256(2)]);
        swapParams[1] = Array.memoryUint256([uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)]);
        swapParams[2] = Array.memoryUint256([uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)]);
        swapParams[3] = Array.memoryUint256([uint256(0), uint256(0), uint256(0), uint256(0), uint256(0)]);

        market.zapDeposit(
            usr1,
            ZapStructDeposit({
                tokenIn: usdc,
                amountIn: 10 ** 6,
                minAmountOut: 0,
                zap: ZapStruct({
                    router: address(pendlePTRouter),
                    routerCall: encoder.encodeSwapTokenForPT(
                        encoder.createCurveRouterNoReceiverNoMinDyStruct(
                            Array.memoryAddress(
                                [
                                    address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48),
                                    address(0x02950460E2b9529D0E00284A5fA2d7bDF3fA4d72),
                                    address(0x4c9EDD5852cd905f086C759E8383e09bff1E68B3),
                                    address(0),
                                    address(0),
                                    address(0),
                                    address(0),
                                    address(0),
                                    address(0)
                                ]
                            ),
                            swapParams,
                            10 ** 6
                        ),
                        PendleSYToPT({
                            market: AddrMarketPendle.USDe_27_11_25,
                            pt: AddrPTPendle.USDe_27_11_25,
                            sy: AddrSYPendle.USDe_27_11_25,
                            underlyingIn: address(AddrClassicERC20.USDe),
                            receiver: address(market),
                            minPTOut: 0
                        })
                    )
                })
            })
        );
    }
}
