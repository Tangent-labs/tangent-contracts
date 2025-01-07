// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IDebtIR} from "./IDebtIR.sol";

interface ICollateral {
    function collatToken() external returns (IERC20Metadata);

    function healthRatio(address account) external returns (uint256);

    function positionValue(address account) external returns (uint256);

    function maxLTV() external returns (uint256);
}
