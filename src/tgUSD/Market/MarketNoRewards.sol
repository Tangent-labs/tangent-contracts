// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MarketExternalActions, MarketCore, Ownable} from "./MarketExternalActions.sol";

import {ILiquidator} from "../../interfaces/internals/tgUSD/ILiquidator.sol";

import "forge-std/console.sol";

/// @notice
contract MarketNoRewards is MarketExternalActions {
    constructor(MarketInit memory _marketInit) MarketCore(_marketInit) {}
    function _preDeposit(address _for, uint256 lpDeposited, bool isStaked) internal view override returns (uint256, IERC20) {
        require(lpDeposited != 0, ZeroCollatAmount());
        return (lpDeposited, collatToken);
    }

    function _transferCollateralDeposit(IERC20 _collatToken, uint256 lpDeposited, uint256 lpStaked, bool isStaked) internal override {
        _collatToken.transferFrom(msg.sender, address(this), lpDeposited);
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw) internal override {
        collatToken.transfer(to, lpToWithdraw);
    }
}
