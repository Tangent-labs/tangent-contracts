// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "../Utilities/abstract/LightOwnable.sol";
abstract contract Sociabilization is LightOwnable {
    /// @notice Percentage of the sociabilization fee in base 100_000.
    uint256 public socFeePercentage;

    /// @notice Pending sociabilization fee to be claimed by the next staker.
    uint256 public socFeePending;

    error ZeroAmountDepositedAfterSociabilization();
    error SocFeeTooHigh();

    /**
     * @notice Computes deposited amount regarding isStake status.
     *         Increments or decrements the pending sociabilization fee.
     * @param amountDeposited New sociabilization fee on a 100_000 basis
     * @param isStake         If true, the whole amount of collateral owned by the market is staked in the underlying protocol and the pending fee is taken by caller.
     *                        Else, the caller is charged a fee and the pending fee is incremented.
     * @param denominator    Percentage basis.
     */
    function _sociabilizationProcess(uint256 amountDeposited, bool isStake, uint256 denominator) internal returns (uint256) {
        if (isStake) {
            amountDeposited += socFeePending;
            delete socFeePending;
        } else {
            uint256 feeTaken = (amountDeposited * socFeePercentage) / denominator;
            socFeePending += feeTaken;
            amountDeposited -= feeTaken;
        }

        return amountDeposited;
    }

    /**
     * @notice Sets the percetage of the sociabilization fee.
     * @dev    Only the contract owner can call this function
     * @param _socFeePercentage New sociabilization fee on a 100_000 basis
     */
    function setSociabilizationFee(uint256 _socFeePercentage) external onlyOwner {
        require(_socFeePercentage < 2_000, SocFeeTooHigh());
        // Claim rewards on behalf
        socFeePercentage = _socFeePercentage;
    }
}
