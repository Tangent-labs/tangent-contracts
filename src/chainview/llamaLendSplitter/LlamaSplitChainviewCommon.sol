// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICommonStruct} from "../../interfaces/internals/ICommonStruct.sol";

import {ISplitterToken} from "../../interfaces/internals/LendSplitter/ISplitterToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LlamaSplitChainviewCommon {
    struct LlamaSplitRow {
        uint256 totalStaked;
        uint256 userStaked;
        ICommonStruct.TokenAmount[] tokensClaimable;
        bool isProcessed;
    }

    function _getRowNotConnected(ISplitterToken splitterToken) public view returns (LlamaSplitRow memory) {
        return
            LlamaSplitRow({
                totalStaked: splitterToken.totalSupply(),
                userStaked: 0,
                tokensClaimable: new ICommonStruct.TokenAmount[](0),
                isProcessed: _getIsProcessed(splitterToken)
            });
    }

    function _getRowConnected(address user, ISplitterToken splitterToken) public view returns (LlamaSplitRow memory) {
        return
            LlamaSplitRow({
                totalStaked: splitterToken.totalSupply(),
                userStaked: splitterToken.balanceOf(user),
                tokensClaimable: splitterToken.claimableRewards(user),
                isProcessed: _getIsProcessed(splitterToken)
            });
    }

    function _getIsProcessed(ISplitterToken splitterToken) public view returns (bool) {
        for (uint256 i; i < 10; i++) {
            try splitterToken.rewardTokens(i) returns (IERC20 rewardToken) {
                (uint128 lastUpdateTime, , , ) = splitterToken.rewardData(rewardToken);
                if (lastUpdateTime >= block.timestamp - 1 weeks) {
                    return true;
                }
            } catch {
                i = 11;
            }
        }
        return false;
    }
}
