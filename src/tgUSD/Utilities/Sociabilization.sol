// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "./LightOwnable.sol";
abstract contract Sociabilization is LightOwnable {
    uint256 public socFeePercentage;
    uint256 public socFeePending;

    error ZeroAmountDepositedAfterSociabilization();
    error SocFeeTooHigh();

    /**
     * @notice Computes deposited amount regarding isStake status.
     *         Allows users
     * @param amountDeposited New sociabilization fee on a 100_000 basis
     * @param isStake         New sociabilization fee on a 100_000 basis
     * @param denominator     New sociabilization fee on a 100_000 basis
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
        require(amountDeposited != 0, ZeroAmountDepositedAfterSociabilization());

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
