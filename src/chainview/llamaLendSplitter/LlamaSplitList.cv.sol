// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {LlamaSplitChainviewCommon} from "./LlamaSplitChainviewCommon.sol";
import {ISplitterToken} from "../../interfaces/internals/LendSplitter/ISplitterToken.sol";
import {IAggregatorV3} from "../../interfaces/externals/Chainlink/IAggregatorV3.sol";

contract LlamaSplitList is LlamaSplitChainviewCommon {
    error LlamaSplitListError(LlamaSplitRow[] list);

    constructor(address user, ISplitterToken[] memory splitterTokens) {
        revert LlamaSplitListError(_getList(user, splitterTokens));
    }

    function _getList(address user, ISplitterToken[] memory splitterTokens) public view returns (LlamaSplitRow[] memory) {
        if (user == address(0)) {
            return _getListNotConnected(splitterTokens, _getCrvUSDPrice());
        } else {
            return _getListConnected(user, splitterTokens, _getCrvUSDPrice());
        }
    }

    function _getListNotConnected(ISplitterToken[] memory splitterTokens, uint256 crvUsdPrice) public view returns (LlamaSplitRow[] memory) {
        LlamaSplitRow[] memory list = new LlamaSplitRow[](splitterTokens.length);
        for (uint256 i; i < list.length; i++) {
            list[i] = _getRowNotConnected(splitterTokens[i], crvUsdPrice);
        }
        return list;
    }

    function _getListConnected(address user, ISplitterToken[] memory splitterTokens, uint256 crvUsdPrice) public view returns (LlamaSplitRow[] memory) {
        LlamaSplitRow[] memory list = new LlamaSplitRow[](splitterTokens.length);
        for (uint256 i; i < list.length; i++) {
            list[i] = _getRowConnected(user, splitterTokens[i], crvUsdPrice);
        }
        return list;
    }
}
