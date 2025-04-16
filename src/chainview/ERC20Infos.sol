// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {TokenAmount} from "../interfaces/internals/ICommonStruct.sol";

struct ERC20AmountInfos {
    IERC20Metadata token;
    uint256 amount;
    uint256 decimals;
    string symbol;
}

struct ERC20StaticInfos {
    IERC20Metadata token;
    uint256 decimals;
    string symbol;
}
abstract contract ERC20Infos {
    function getERC20AmountInfos(TokenAmount memory tokenAmount) public view returns (ERC20AmountInfos memory) {
        IERC20Metadata erc20Meta = IERC20Metadata(address(tokenAmount.token));
        return ERC20AmountInfos({token: erc20Meta, amount: tokenAmount.amount, decimals: erc20Meta.decimals(), symbol: erc20Meta.symbol()});
    }

    function getERC20AmountInfos(TokenAmount[] memory tokenAmounts) public view returns (ERC20AmountInfos[] memory) {
        ERC20AmountInfos[] memory amountInfos = new ERC20AmountInfos[](tokenAmounts.length);
        for (uint256 i; i < tokenAmounts.length; ) {
            amountInfos[i] = getERC20AmountInfos(tokenAmounts[i]);
            unchecked {
                ++i;
            }
        }
        return amountInfos;
    }

    function getERC20StaticInfos(IERC20 erc20) public view returns (ERC20StaticInfos memory) {
        IERC20Metadata erc20Meta = IERC20Metadata(address(erc20));
        return ERC20StaticInfos({token: erc20Meta, decimals: erc20Meta.decimals(), symbol: erc20Meta.symbol()});
    }

    function getERC20StaticInfos(IERC20[] memory erc20s) public view returns (ERC20StaticInfos[] memory) {
        ERC20StaticInfos[] memory infos = new ERC20StaticInfos[](erc20s.length);
        for (uint256 i; i < erc20s.length; ) {
            infos[i] = getERC20StaticInfos(erc20s[i]);
            unchecked {
                ++i;
            }
        }
        return infos;
    }
}
