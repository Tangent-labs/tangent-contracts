// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IMarketExternalActions {
    function deposit(address _for, uint256 lpDeposited, bool isStaked) external;

    function borrow(address receiver, uint256 tgUSDToBorrow) external;

    function depositAndBorrow(uint256 lpDeposited, uint256 debtBorrow, bool isStaked, address callerZapper) external;

    function repay(address account, uint256 tgUSDToRepay, address callerZapper) external;

    function liquidate(address account, uint256 tgUSDToRepay, address liquidator, uint256 minTgUSDOut, bytes calldata liquidationCall) external;

    function processRewards(address harvestFeeReceiver) external;
}
