// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Aave V3 flash loan simple receiver callback interface
interface IFlashLoanSimpleReceiver {
    /// @notice Called by the Aave Pool after the flash-borrowed asset has been transferred
    /// @param asset The address of the flash-borrowed asset
    /// @param amount The amount flash-borrowed
    /// @param premium The fee to repay on top of the borrowed amount
    /// @param initiator The address that initiated the flash loan
    /// @param params Arbitrary bytes passed from the flash loan call
    /// @return true if the operation succeeded
    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes calldata params) external returns (bool);
}
