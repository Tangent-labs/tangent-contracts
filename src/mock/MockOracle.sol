// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {OracleBase} from "../USG/Oracles/OracleBase.sol";

contract MockOracle is OracleBase {
    uint256 public lastAns;

    constructor() OracleBase("Mock") {
        lastAns = 1 ether;
    }

    function setLastAnswer(uint256 _lastAns) external {
        lastAns = _lastAns;
    }

    function minus() external {
        lastAns = (lastAns * 70) / 100;
    }

    function latestAnswer(bool isNoFailMode) external view override returns (uint256) {
        return lastAns;
    }

    function latestAnswerUpdate(bool isNoFailMode) external returns (uint256) {
        return lastAns;
    }
}
