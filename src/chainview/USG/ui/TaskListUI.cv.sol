// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IDebtIR} from "../../../interfaces/internals/USG/IDebtIR.sol";
import {IMarketViewer} from "../../../interfaces/internals/USG/IMarketViewer.sol";

contract TaskListUI {
    error TaskListUIError(uint256[] balances);

    constructor(address account, IDebtIR[] memory markets, IERC20[] memory tokens, IMarketViewer marketViewer) {
        uint256[] memory balances = new uint256[](tokens.length + 1);

        for (uint256 i; i < tokens.length; ) {
            // Low-level staticcall so a broken or codeless token (e.g. a synthetic
            // points-DB address with no contract) yields 0 instead of reverting the batch
            (bool ok, bytes memory data) = address(tokens[i]).staticcall(
                abi.encodeWithSelector(IERC20.balanceOf.selector, account)
            );
            balances[i] = (ok && data.length >= 32) ? abi.decode(data, (uint256)) : 0;
            unchecked {
                ++i;
            }
        }
        uint256 debt;
        for (uint256 i; i < markets.length; ) {
            debt += marketViewer.userDebt(markets[i], account);
            unchecked {
                ++i;
            }
        }

        balances[tokens.length] = debt;
        revert TaskListUIError(balances);
    }
}
