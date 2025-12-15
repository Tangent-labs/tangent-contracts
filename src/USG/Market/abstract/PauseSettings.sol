// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {LightOwnable} from "../../Utilities/abstract/LightOwnable.sol";
import {IControlTower} from "../../../interfaces/internals/USG/IControlTower.sol";

/// @author Tangent Finance

abstract contract PauseSettings is LightOwnable {
    enum PauseEnum {
        DepositPaused,
        BorrowPaused,
        LeveragePaused
    }
    /// @notice Reference to the ControlTower contract managing market governance and treasury.
    IControlTower controlTower;

    uint64 isInitialized;

    /// @notice Pauses new deposits on the market
    uint64 isDepositPaused;

    /// @notice Pauses new borrows on the market
    uint64 isBorrowPaused;

    /// @notice Pauses new leverages on the market
    uint64 isLeveragePaused;

    error DepositPaused();
    error BorrowPaused();
    error LeveragePaused();
    error CallerNotPauser();

    event PauseTrigger(PauseEnum pauseType, uint64 isPaused);

    modifier isCallerPauser() {
        _verifyIsCallerPauser();
        _;
    }

    function _verifyIsCallerPauser() internal view {
        require(controlTower.isPauser(msg.sender), CallerNotPauser());
    }

    function _verifyIsDepositNotPaused() internal view {
        require(isDepositPaused == 0, DepositPaused());
    }

    function _verifyIsBorrowNotPaused() internal view {
        require(isBorrowPaused == 0, BorrowPaused());
    }

    function setPause(PauseEnum pauseType, uint64 isPaused) external isCallerPauser {
        if (pauseType == PauseEnum.DepositPaused) {
            isDepositPaused = isPaused;
        } else if (pauseType == PauseEnum.BorrowPaused) {
            isBorrowPaused = isPaused;
        } else {
            isLeveragePaused = isPaused;
        }
        emit PauseTrigger(pauseType, isPaused);
    }

    function getPausedSettings() external view returns (uint64, uint64, uint64) {
        return (isDepositPaused, isBorrowPaused, isLeveragePaused);
    }
}
