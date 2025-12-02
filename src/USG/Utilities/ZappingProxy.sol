// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IZappingProxy} from "../../interfaces/internals/USG/IZappingProxy.sol";
import {IControlTower} from "../../interfaces/internals/USG/IControlTower.sol";

import {ZapStruct} from "../../interfaces/internals/ICommonStruct.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {LightReentrancyGuardTransient} from "../Utilities/abstract/LightReentrancyGuardTransient.sol";

/// @title ZappingProxy
/// @author Tangent Finance
/// @notice This contract is used to zap tokens in and out of the system. Tokens are transiting to this contract and are pulled by the router passed in parameters.
///         NO TOKENS SHOULD BE SEND DIRECTLY HERE OR THEY WILL BE POTENTIALLY IMMEDIATLY STOLEN
contract ZappingProxy is IZappingProxy, LightReentrancyGuardTransient {
    using SafeERC20 for IERC20;

    uint256 constant MAX_UINT = type(uint256).max;
    address constant CHAIN_COIN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    IControlTower public controlTower;

    error ZapCallError(bytes);
    error MinAmountOutNotReached();
    error TokenInOutMustBeDifferent();
    error TokenInMustNotBeETH();
    error TokenInMustBeETH();

    constructor(IControlTower _controlTower) {
        controlTower = _controlTower;
    }

    /**
     * @notice Allow a tokenIn to be spend by a router, call the router and ensure that the router returned a minimum amount of tokenOut afterwards.
     * @param tokenIn      Token to be spent by the router
     * @param tokenOut     Token to be received by the `receiver`
     * @param minAmountOut Minimum amount of token out received by the `receiver`
     * @param receiver     Contract receiving the tokenOut
     * @param zap          Struct containing the router and the raw bytes data that will be executed
     * @return Amount of tokenOut received
     */
    function zapProxy(IERC20 tokenIn, IERC20 tokenOut, uint256 minAmountOut, address receiver, ZapStruct calldata zap) public payable nonReentrant returns (uint256) {
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

        uint256 balanceTokenInLeft;

        // In case some tokenIn are left, we send it back to the DAO.
        if (msg.value == 0) {
            balanceTokenInLeft = tokenIn.balanceOf(address(this));
            if (0 != balanceTokenInLeft) {
                tokenIn.safeTransfer(controlTower.feeTreasury(), balanceTokenInLeft);
            }
        } else {
            balanceTokenInLeft = address(this).balance;
            if (0 != balanceTokenInLeft) {
                (bool isSuccess, ) = payable(controlTower.feeTreasury()).call{value: balanceTokenInLeft}("");
                require(isSuccess, ZapCallError(""));
            }
        }

        return bal;
    }

    // Receive ETH sent
    receive() external payable {}
}
