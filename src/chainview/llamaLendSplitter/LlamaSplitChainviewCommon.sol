// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {TokenAmount} from "../../interfaces/internals/ICommonStruct.sol";

import {ISplitterToken} from "../../interfaces/internals/LendSplitter/ISplitterToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAggregatorV3} from "../../interfaces/externals/Chainlink/IAggregatorV3.sol";

contract LlamaSplitChainviewCommon {
    struct LlamaSplitRow {
        uint256 totalStakedAmount;
        uint256 totalStakedDollar;
        uint256 userStakedAmount;
        uint256 userStakedDollar;
        bool isProcessed;
        TokenAmount[] tokensClaimable;
    }
    function _getCrvUSDPrice() public view returns (uint256) {
        IAggregatorV3 crvUSDOracle = IAggregatorV3(0xEEf0C605546958c1f899b6fB336C20671f9cD49F);
        (, int256 crvUsdPrice, , , ) = crvUSDOracle.latestRoundData();

        return uint256(crvUsdPrice) * 10 ** (18 - crvUSDOracle.decimals());
    }

    function _getRowNotConnected(ISplitterToken splitterToken, uint256 crvUSDPrice) public view returns (LlamaSplitRow memory) {
        uint256 totalStakedAmount = splitterToken.totalSupply();
        return
            LlamaSplitRow({
                totalStakedAmount: totalStakedAmount,
                totalStakedDollar: (totalStakedAmount * crvUSDPrice) / 10 ** 18,
                userStakedAmount: 0,
                userStakedDollar: 0,
                tokensClaimable: new TokenAmount[](0),
                isProcessed: _getIsProcessed(splitterToken)
            });
    }

    function _getRowConnected(address user, ISplitterToken splitterToken, uint256 crvUSDPrice) public view returns (LlamaSplitRow memory) {
        uint256 totalStakedAmount = splitterToken.totalSupply();
        uint256 userStakedAmount = splitterToken.balanceOf(user);
        return
            LlamaSplitRow({
                totalStakedAmount: splitterToken.totalSupply(),
                totalStakedDollar: (totalStakedAmount * crvUSDPrice) / 10 ** 18,
                userStakedAmount: userStakedAmount,
                userStakedDollar: (userStakedAmount * crvUSDPrice) / 10 ** 18,
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
