// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IDebtIR} from "./IDebtIR.sol";
import {IRewardAccumulator} from "./IRewardAccumulator.sol";
import {IPriceOracle} from "./IPriceOracle.sol";

interface ICollateral {
    function collatOracle() external view returns (IPriceOracle);

    function collatToken() external view returns (IERC20Metadata);

    function collatDecimals() external view returns (uint256);

    function collateralBalances(address account) external view returns (uint256);

    function totalCollateral() external view returns (uint256);

    function maxLTV() external view returns (uint256);

    function liquidationThreshold() external view returns (uint256);

    function rewardAccumulator() external view returns (IRewardAccumulator);

    function getBalanceAndTotalCollateral(address account) external view returns (uint256, uint256);
}
