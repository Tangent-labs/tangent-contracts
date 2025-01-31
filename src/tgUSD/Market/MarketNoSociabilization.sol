// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MarketInit, GlobalMarketInitParams} from "../../interfaces/internals/tgUSD/IMarketCore.sol";

import {MarketExternalActions} from "./abstract/MarketExternalActions.sol";

import "forge-std/console.sol";

/// @notice
contract MarketNoSociabilization is MarketExternalActions {
    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit) external {
        // Common
        _initializationCommon(_marketConstants, _marketInit);
    }

    function _preDeposit(address _for, uint256 lpDeposited, bool isStaked) internal override updateReward(_for) returns (uint256, IERC20) {
        require(lpDeposited != 0, ZeroCollatAmount());
        return (lpDeposited, collatToken);
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw) internal override {
        collatToken.transfer(to, lpToWithdraw);
    }

    /**
     * @notice Process the rewards for the market
     * @dev Streams all accumulated rewards to the stakers.
     *      Anyone can trigger this function and will be incentivized with an harvester fee.
     */
    function processRewards(address harvestFeeReceiver) external override updateReward(address(0)) {
        // Stream rewards to stakers and give rewards to harvester
        _processRewards(harvestFeeReceiver);
    }
}
