// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../../interfaces/internals/USG/IPriceOracle.sol";

abstract contract OracleBase is IPriceOracle {
    function decimals() external pure returns (uint8) {
        return 18;
    }

    function latestAnswer() external view virtual returns (uint256);

    /**
     * @notice Internal function to get the latest price from an oracle
     * @param _oracle The oracle to get the price from
     * @param oracleDecimals The number of decimals used by the oracle
     * @return The latest price from the oracle, adjusted to 18 decimals
     */
    function _coinPrice(IPriceOracle _oracle, uint256 oracleDecimals) internal view returns (uint256) {
        return _oracle.latestAnswer() * 10 ** (18 - oracleDecimals);
    }
}
