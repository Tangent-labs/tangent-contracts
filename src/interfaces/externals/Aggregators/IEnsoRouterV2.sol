// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

enum TokenType {
    Native,
    ERC20,
    ERC721,
    ERC1155
}
struct Token {
    TokenType tokenType;
    bytes data;
}
interface IEnsoRouterV2 {
    function routeMulti(Token[] calldata tokensIn, bytes calldata data) external returns (bytes calldata response);
    function routeSingle(Token calldata tokenIn, bytes calldata data) external returns (bytes calldata response);
    function safeRouteMulti(Token[] calldata tokensIn, Token[] calldata tokensOut, address receiver, bytes calldata data) external returns (bytes memory response);
    function safeRouteSingle(Token calldata tokenIn, Token calldata tokenOut, address receiver, bytes calldata data) external returns (bytes memory response);
    function shortcuts() external view returns (address);
}
