// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../../interfaces/internals/USG/IPriceOracle.sol";

abstract contract OracleBase is IPriceOracle {
    string public oracleName;
    constructor(string memory _oracleName) {
        oracleName = _oracleName;
    }
    function decimals() external pure returns (uint8) {
        return 18;
    }

    function latestAnswer(bool isNoFailMode) external view virtual returns (uint256);
}
