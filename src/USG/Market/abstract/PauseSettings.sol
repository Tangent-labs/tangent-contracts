// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {LightOwnable} from "../../Utilities/abstract/LightOwnable.sol";
import {IControlTower} from "../../../interfaces/internals/USG/IControlTower.sol";

abstract contract PauseSettings is LightOwnable {
    /// @notice Reference to the ControlTower contract managing market governance and treasury.
    IControlTower controlTower;

    bool public isInitialized;

    /// @notice Pauses new deposits on the market
    bool public isDepositPaused;

    /// @notice Pauses new borrows on the market
    bool public isBorrowPaused;

    /// @notice Pauses new leverages on the market
    bool public isLeveragePaused;

    error DepositPaused();
    error BorrowPaused();
    error LeveragePaused();
    error CallerNotPauser();

    modifier isCallerPauser() {
        _verifyIsCallerPauser();
        _;
    }

    function _verifyIsCallerPauser() internal view {
        require(controlTower.isPauser(msg.sender), CallerNotPauser());
    }

    function _verifyIsDepositNotPaused() internal view {
        require(!isDepositPaused, DepositPaused());
    }

    function _verifyIsBorrowNotPaused() internal view {
        require(!isBorrowPaused, BorrowPaused());
    }

    function setIsDepositPaused(bool _isDepositPaused) external isCallerPauser {
        isDepositPaused = _isDepositPaused;
    }
    function setIsBorrowPaused(bool _isBorrowPaused) external isCallerPauser {
        isBorrowPaused = _isBorrowPaused;
    }
    function setIsLeveragePaused(bool _isLeveragePaused) external isCallerPauser {
        isLeveragePaused = _isLeveragePaused;
    }
}
