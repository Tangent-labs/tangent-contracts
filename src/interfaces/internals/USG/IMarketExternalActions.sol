// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20, TokenAmount, ZapStruct} from "../ICommonStruct.sol";

interface IMarketExternalActions {
    function deposit(address _for, uint256 lpDeposited, bool isStaked) external;

    function borrow(address receiver, uint256 USGToBorrow) external;

    function depositAndBorrow(uint256 lpDeposited, uint256 debtBorrow, bool isStaked) external;

    function repay(address account, uint256 USGToRepay) external;

    function liquidate(address account, uint256 USGToRepay, uint256 minUSGOut, ZapStruct calldata zap) external;

    function leverage(uint256 collatToDeposit, uint256 USGToFlashMint, uint256 minCollatAmountOut, bool isStaked, ZapStruct calldata zap) external;

    function claimUnderlyingRewards(IERC20[] memory _rewardTokens) external returns (TokenAmount[] memory);
}
