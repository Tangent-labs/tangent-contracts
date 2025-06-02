// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IZappingProxy} from "../../interfaces/internals/tgUSD/IZappingProxy.sol";
import {ZapStruct} from "../../interfaces/internals/ICommonStruct.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "forge-std/console.sol";

/// @title ZappingProxy
/// @notice This contract is used to zap tokens in and out of the system. Tokens are transiting to this contract and are pulled by the router passed in parameters.

contract ZappingProxy is IZappingProxy {
    using SafeERC20 for IERC20;

    uint256 constant MAX_UINT = type(uint256).max;
    address constant CHAIN_COIN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    error ZapCallError(bytes);
    error MinAmountOutNotReached();
    error TokenInOutMustBeDifferent();
    error TokenInMustNotBeETH();
    error TokenInMustBeETH();

    function zapProxy(IERC20 tokenIn, IERC20 tokenOut, uint256 minAmountOut, address receiver, ZapStruct calldata zap) external payable returns (uint256) {
        address router = zap.router;
        require(tokenIn != tokenOut, TokenInOutMustBeDifferent());
        if (msg.value == 0) {
            // TokenIn must be different from chain coin if no ETH is sent
            require(address(tokenIn) != CHAIN_COIN, TokenInMustNotBeETH());
            if (tokenIn.allowance(address(this), router) != MAX_UINT) {
                tokenIn.forceApprove(router, MAX_UINT);
            }
        } else {
            require(address(tokenIn) == CHAIN_COIN, TokenInMustBeETH());
        }

        uint256 bal = tokenOut.balanceOf(receiver);
        // Call router router and perform the swaps with raw data.
        (bool isRouterCallSuccess, bytes memory data) = router.call{value: msg.value}(zap.routerCall);
        // Verify the call to router was successfull
        require(isRouterCallSuccess, ZapCallError(data));
        bal = tokenOut.balanceOf(receiver) - bal;
        require(minAmountOut <= bal, MinAmountOutNotReached());

        return bal;
    }
}
