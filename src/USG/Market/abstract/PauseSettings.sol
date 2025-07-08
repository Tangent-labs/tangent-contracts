// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {LightOwnable} from "../../Utilities/abstract/LightOwnable.sol";
abstract contract PauseSettings is LightOwnable {
    address public pauser;

    bool public isInitialized;

    bool public isDepositPaused;

    bool public isBorrowPaused;

    bool public isLeveragePaused;

    function setIsDepositPaused(bool _isDepositPaused) external {
        require(msg.sender == pauser);
        isDepositPaused = _isDepositPaused;
    }
    function setIsBorrowPaused(bool _isBorrowPaused) external {
        require(msg.sender == pauser);
        isBorrowPaused = _isBorrowPaused;
    }
    function setIsLeveragePaused(bool _isLeveragePaused) external {
        require(msg.sender == pauser);
        isLeveragePaused = _isLeveragePaused;
    }

    function setPauser(address _newPauser) external onlyOwner {
        pauser = _newPauser;
    }
}
