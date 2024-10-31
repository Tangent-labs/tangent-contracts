// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import {ICommonStruct} from "../../interfaces/internals/ICommonStruct.sol";

import {BalancesAllowances} from "../BalancesAllowances.sol";
import {LlamaSplitChainviewCommon} from "./LlamaSplitChainviewCommon.sol";

import {ILlamaVault} from "../../interfaces/externals/LlamaLend/ILlamaVault.sol";
import {ISplitterToken} from "../../interfaces/internals/LendSplitter/ISplitterToken.sol";
import {ILendRewardSplitter} from "../../interfaces/internals/LendSplitter/ILendRewardSplitter.sol";

contract LlamaSplitDetail is LlamaSplitChainviewCommon, BalancesAllowances {
    ILendRewardSplitter lendSplitter;

    struct OutputLlamaSplitDetail {
        OutputBalanceAllowances[] obas;
        LlamaSplitRow detail;
    }

    error LlamaSplitDetailError(OutputLlamaSplitDetail output);

    constructor(address user, ILendRewardSplitter _lendSplitter, ISplitterToken splitterToken) {
        lendSplitter = _lendSplitter;
        revert LlamaSplitDetailError(_getDetail(user, splitterToken));
    }

    function _getDetail(address user, ISplitterToken splitterToken) public view returns (OutputLlamaSplitDetail memory) {
        if (user == address(0)) {
            return OutputLlamaSplitDetail({obas: new OutputBalanceAllowances[](0), detail: _getRowNotConnected(splitterToken)});
        } else {
            return OutputLlamaSplitDetail({obas: _getBalAllow(user, splitterToken), detail: _getRowConnected(user, splitterToken)});
        }
    }

    function _getBalAllow(address user, ISplitterToken splitterToken) internal view returns (OutputBalanceAllowances[] memory) {
        address[] memory spender = new address[](1);
        spender[0] = address(lendSplitter);

        ILlamaVault llamaVault = splitterToken.llamaVault();

        InputBalancesAllowances[] memory ibas = new InputBalancesAllowances[](2);
        ibas[0] = InputBalancesAllowances({token: lendSplitter.lentAssetPerLlamaVault(llamaVault), spenders: spender});
        ibas[1] = InputBalancesAllowances({token: llamaVault, spenders: spender});

        return getBalancesAllowances(user, ibas);
    }
}
