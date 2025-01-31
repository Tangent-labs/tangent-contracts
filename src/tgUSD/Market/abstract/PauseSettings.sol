// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {LightOwnable} from "../../Utilities/LightOwnable.sol";
abstract contract PauseSettings is LightOwnable {
    bool public isInitialized;

    bool public isDepositPaused;

    bool public isBorrowPaused;

    bool public isLeveragePaused;

    function setIsDepositPaused(bool _isDepositPaused) external onlyOwner {
        isDepositPaused = _isDepositPaused;
    }
    function setIsBorrowPaused(bool _isBorrowPaused) external onlyOwner {
        isBorrowPaused = _isBorrowPaused;
    }
    function setIsLeveragePaused(bool _isLeveragePaused) external onlyOwner {
        isLeveragePaused = _isLeveragePaused;
    }
}
