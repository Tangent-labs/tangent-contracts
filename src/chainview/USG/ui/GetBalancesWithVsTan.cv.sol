// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IVsTan} from "../../../interfaces/internals/USG/IVsTan.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract GetBalancesWithVsTan {
    struct TokenBalance {
        address token;
        uint256 balance;
    }
    error GetBalancesWithVsTanError(TokenBalance[] out);
    constructor(address user, IERC20[] memory tokens, IVsTan vsTan) {
        uint256 totalLen = tokens.length + 1;
        TokenBalance[] memory out = new TokenBalance[](totalLen);
        for (uint256 i = 0; i < out.length - 1; i++) {
            out[i] = TokenBalance({token: address(tokens[i]), balance: tokens[i].balanceOf(user)});
        }

        uint256 vsTanPositionOwned = vsTan.balanceOf(user);
        uint256 totalVsTan;
        for (uint256 i = 0; i < vsTanPositionOwned; i++) {
            uint256 tokenId = vsTan.tokenOfOwnerByIndex(user, i);
            (, uint208 vsTanAmount) = vsTan.locks(tokenId);
            totalVsTan += vsTanAmount;
        }

        out[totalLen - 1] = TokenBalance({token: address(vsTan), balance: totalVsTan});
        revert GetBalancesWithVsTanError(out);
    }
}
