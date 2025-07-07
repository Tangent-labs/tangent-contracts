// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
import {IZappingProxy} from "../../../interfaces/internals/USG/IZappingProxy.sol";
import {ZapStructDeposit, IERC20} from "../../../interfaces/internals/ICommonStruct.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract ZappingUtil {
    using SafeERC20 for IERC20;
    address constant CHAIN_COIN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    IZappingProxy public zappingProxy;

    error InvalidZapValue();

    function _zapDeposit(ZapStructDeposit calldata zapCall, IERC20 tokenOut, address receiver) internal returns (uint256) {
        require(0 != zapCall.amountIn, InvalidZapValue());
        IZappingProxy _zappingProxy = zappingProxy;

        if (address(zapCall.tokenIn) != CHAIN_COIN) {
            require(0 == msg.value, InvalidZapValue());
            zapCall.tokenIn.safeTransferFrom(msg.sender, address(_zappingProxy), zapCall.amountIn);
        } else {
            require(msg.value == zapCall.amountIn, InvalidZapValue());
        }

        return _zappingProxy.zapProxy{value: msg.value}(zapCall.tokenIn, tokenOut, zapCall.minAmountOut, receiver, zapCall.zap);
    }
}
