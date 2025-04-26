// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20, TokenAmount, ZapStruct} from "../ICommonStruct.sol";

interface IMarketExternalActions {
    function deposit(address _for, uint256 lpDeposited, bool isStaked, ZapStruct calldata zap) external;

    function borrow(address receiver, uint256 tgUSDToBorrow) external;

    function depositAndBorrow(uint256 lpDeposited, uint256 debtBorrow, bool isStaked, ZapStruct calldata zap) external;

    function repay(address account, uint256 tgUSDToRepay, ZapStruct calldata zap) external;

    function liquidate(address account, uint256 tgUSDToRepay, uint256 minTgUSDOut, ZapStruct calldata zap) external;

    function claimUnderlyingRewards(IERC20[] memory _rewardTokens) external returns (TokenAmount[] memory);
}
