// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPendleRouter {
    struct ApproxParams {
        uint256 guessMin;
        uint256 guessMax;
        uint256 guessOffchain;
        uint256 maxIteration;
        uint256 eps;
        uint256 guessPrecision;
    }

    struct TokenInput {
        address tokenIn;
        uint256 amountIn;
        address router;
        address extRouter;
        bytes extCalldata;
    }

    struct LimitOrderData {
        bytes32 someHash;
        uint256 someValue;
    }

    function addLiquiditySingleToken(
        address receiver,
        address market,
        uint256 minLpOut,
        ApproxParams calldata guessParams,
        TokenInput calldata input,
        LimitOrderData calldata limitOrder
    ) external returns (uint256);

    function addLiquiditySingleTokenKeepYt(
        address receiver,
        address market,
        uint256 minLpOut,
        ApproxParams calldata guessParams,
        TokenInput calldata input,
        LimitOrderData calldata limitOrder
    ) external returns (uint256);

    function removeLiquiditySingleToken(address receiver, address market, uint256 lpToBurn, address tokenOut, uint256 minTokenOut) external returns (uint256);
}
