// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Utilities/abstract/LightOwnable.sol";

abstract contract Sociabilization is LightOwnable {
    /// @notice Percentage of the sociabilization fee in base 100_000.
    uint256 public socFeePercentage;

    /// @notice Pending sociabilization fee to be claimed by the next staker.
    uint256 public socFeePending;

    error ZeroAmountDepositedAfterSociabilization();
    error SocFeeTooHigh();
    error NothingToStake();

    function _initializeSociabilization(uint256 _socFeePercentage) internal {
        require(_socFeePercentage <= 2_000, SocFeeTooHigh());
        socFeePercentage = _socFeePercentage;
    }
    /**
     * @notice Computes deposited amount regarding isStake status.
     *         Increments or decrements the pending sociabilization fee.
     * @param amountDeposited New sociabilization fee on a 100_000 basis
     * @param isStake         If true, the whole amount of collateral owned by the market is staked in the underlying protocol and the pending fee is taken by caller.
     *                        Else, the caller is charged a fee and the pending fee is incremented.
     * @param denominator    Percentage basis.
     */
    function _sociabilizationProcess(uint256 amountDeposited, bool isStake, uint256 denominator) internal returns (uint256) {
        uint256 _socFeePending = socFeePending;
        if (isStake) {
            // Save gas by not updating pending fee if it's 0
            if (_socFeePending != 0) {
                amountDeposited += _socFeePending;
                delete socFeePending;
            }
        }
        // User prefers to save gas
        else {
            uint256 feeTaken = (amountDeposited * socFeePercentage) / denominator;
            socFeePending = feeTaken + _socFeePending;
            amountDeposited -= feeTaken;
        }

        return amountDeposited;
    }

    function _stakeAll(address receiver, IERC20 _collatToken) internal returns (uint256) {
        uint256 _balance = _collatToken.balanceOf(address(this));
        require(_balance != 0, NothingToStake());
        uint256 _socFeePending = socFeePending;
        if (_socFeePending != 0) {
            _collatToken.transfer(receiver, _socFeePending);
            _balance -= _socFeePending;
            delete socFeePending;
        }

        return _balance;
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
