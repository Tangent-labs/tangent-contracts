// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {ILlamaLendVault} from "../../src/interfaces/externals/ILlamaLendVault.sol";

contract ZapAndDepositReentrancyAttack {
    LendRewardSplitter target;
    bool public hasReentered = false;

    constructor(address _target) {
        target = LendRewardSplitter(_target);
    }

    function startAttack(
        ILlamaLendVault _llamaLendVault,
        uint256 _inAmount,
        uint256 _minLendAssetAmount,
        bool isCvx,
        bool _isStableReward,
        bool _doDeposit,
        address[11] memory _routes,
        address[5] memory _pools,
        uint256[5][5] memory _swapParams
    ) public payable {
        // Trigger zapAndDeposit function
        target.zapAndDeposit{value: msg.value}(
            _llamaLendVault,
            _inAmount,
            _minLendAssetAmount,
            isCvx,
            _isStableReward,
            _doDeposit,
            _routes,
            _pools,
            _swapParams
        );
    }

    receive() external payable {
        hasReentered = true;
    }

    fallback() external payable {
        hasReentered = true;
    }
}
