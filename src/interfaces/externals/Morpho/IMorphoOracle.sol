// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Morpho Blue oracle (named IOracle upstream): price of 1 collateral token
/// quoted in loan token, scaled by 1e36 * 10^(loanDecimals - collateralDecimals).
interface IMorphoOracle {
    function price() external view returns (uint256);
}
