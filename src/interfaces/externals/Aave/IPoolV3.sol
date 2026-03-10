// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal Aave V3 Pool interface for flash loans
interface IPoolV3 {
    /// @notice Execute a simple flash loan (single asset)
    /// @param receiverAddress Contract implementing executeOperation callback
    /// @param asset The address of the asset to flash-borrow
    /// @param amount The amount to flash-borrow
    /// @param params Arbitrary bytes passed to the receiver's executeOperation
    /// @param referralCode Referral code (use 0 if none)
    function flashLoanSimple(address receiverAddress, address asset, uint256 amount, bytes calldata params, uint16 referralCode) external;

    /// @notice The total flash loan premium in bps (e.g. 5 = 0.05%)
    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128);
}
