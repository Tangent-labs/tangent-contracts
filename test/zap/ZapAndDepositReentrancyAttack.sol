// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LendRewardSplitter} from "../../src/LendRewardSplitter.sol";
import {ILlamaVault} from "../../src/interfaces/externals/ILlamaVault.sol";

contract ZapAndDepositReentrancyAttack {
    LendRewardSplitter target;
    bool public hasReentered = false;

    constructor(address _target) {
        target = LendRewardSplitter(_target);
    }

    function startAttack(
        ILlamaVault _llamaLendVault,
        uint256 _inAmount,
        uint256 _minLendAssetAmount,
        bool _isStableReward,
        bool _isAutoCompound,
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
            _isStableReward,
            _isAutoCompound,
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
