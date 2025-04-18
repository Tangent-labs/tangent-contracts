// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
interface IEnsoRouterV1 {
    function enso() external view returns (address);
    function routeSingle(address tokenIn, uint256 amountIn, bytes32[] memory commands, bytes[] memory state) external returns (bytes[] memory returnData);
    function safeRouteSingle(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        bytes32[] memory commands,
        bytes[] memory state
    ) external returns (bytes[] memory returnData);
}
