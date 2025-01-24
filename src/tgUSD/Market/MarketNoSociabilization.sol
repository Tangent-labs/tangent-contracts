// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Rewards, IRewardAccumulator, IERC20Metadata, IERC20} from "./abstract/Rewards.sol";

import "forge-std/console.sol";

/// @notice
contract MarketNoSociabilization is Rewards {
    function initialize(MarketConstants memory _marketConstants, MarketInit memory _marketInit) external {
        // Common
        _initializationCommon(_marketConstants, _marketInit);
    }

    function _preDeposit(address _for, uint256 lpDeposited, bool isStaked) internal view override returns (uint256, IERC20) {
        require(lpDeposited != 0, ZeroCollatAmount());
        return (lpDeposited, collatToken);
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw) internal override {
        collatToken.transfer(to, lpToWithdraw);
    }
}
