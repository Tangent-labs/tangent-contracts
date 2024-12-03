// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IMarketCore} from "./IMarketCore.sol";
interface IMarketExternalActions {
    function deposit(address _for, uint256 lpDeposited, bool isStaked) external;

    function depositAndBorrow(address _for, uint256 lpDeposited, uint256 debtBorrow, bool isStaked) external;

    function repay(address account, uint256 tgUSDToRepay, address callerZapper) external;
}
