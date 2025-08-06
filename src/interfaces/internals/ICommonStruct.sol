// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct TokenAmount {
    IERC20 token;
    uint256 amount;
}
struct ZapStruct {
    address router;
    bytes routerCall;
}
struct ZapStructDeposit {
    IERC20 tokenIn;
    uint256 amountIn;
    uint256 minAmountOut;
    ZapStruct zap;
}

struct ZapStructDepositNoMinAmount {
    IERC20 tokenIn;
    uint256 amountIn;
    ZapStruct zap;
}
