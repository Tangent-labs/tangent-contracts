// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MarketInit, GlobalMarketInitParams} from "../../interfaces/internals/tgUSD/IMarketCore.sol";
import {TokenAmount} from "../../interfaces/internals/ICommonStruct.sol";
import {MarketExternalActions} from "./abstract/MarketExternalActions.sol";

/// @notice
contract MarketNoSociabilization is MarketExternalActions {
    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit) external {
        // Common
        _initializationCommon(_marketConstants, _marketInit);
    }

    function _transferCollateralWithdraw(address to, uint256 lpToWithdraw) internal override {
        collatToken.transfer(to, lpToWithdraw);
    }

    /**
     * @notice Claim and process the governance rewards
     * @dev Claim rewards from the corresponding ConvexReward SC and streams them for the stakers.
     *      Anyone can trigger this function and will be incentivized with a processor fee.
     */
    function claimUnderlyingRewards(IERC20[] memory _rewardTokens) external override nonReentrant updateRewards(address(0)) returns (TokenAmount[] memory) {
        require(msg.sender == address(rewardAccumulator), NotRewardAccumulator());
        return _claimUnderlyingRewards(_rewardTokens);
    }
}
