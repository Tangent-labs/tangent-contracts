// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../../interfaces/internals/USG/IPriceOracle.sol";
import "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";

import {OracleBase} from "../OracleBase.sol";

/// @title OracleDuoPoolStable
/// @notice This contract provides price oracle functionality for a dual pool stablePool of Curve Finance.
contract OracleDuoPoolStable is OracleBase {
    /// @notice Struct to store oracle parameters
    struct OracleDuoPoolStruct {
        /// @dev Oracle for the first coin
        IPriceOracle coin0Oracle;
        /// @dev Oracle for the second coin
        IPriceOracle coin1Oracle;
        /// @dev Curve stable swap pool
        ICurveStableSwapNG lp;
        /// @dev Decimals for the first coin's oracle
        uint16 coin0OracleDecimals;
        /// @dev Decimals for the second coin's oracle
        uint16 coin1OracleDecimals;
    }

    /// @notice Public variable to store oracle parameters
    OracleDuoPoolStruct public params;

    /**
     * @notice Constructor to initialize the OracleDuoPoolStable contract
     * @param _lp Address of the Curve stable swap pool
     * @param _coin0Oracle Address of the oracle for the first coin
     * @param _coin1Oracle Address of the oracle for the second coin
     */
    constructor(address _lp, IPriceOracle _coin0Oracle, IPriceOracle _coin1Oracle) {
        params = OracleDuoPoolStruct({
            coin0Oracle: _coin0Oracle,
            coin1Oracle: _coin1Oracle,
            lp: ICurveStableSwapNG(_lp),
            coin0OracleDecimals: uint16(_coin0Oracle.decimals()),
            coin1OracleDecimals: uint16(_coin1Oracle.decimals())
        });
    }

    /**
     * @notice Returns the latest price from the oracle
     * @return The price of the stable pool, adjusted to 18 decimals
     */
    function latestAnswer() external view override returns (uint256) {
        OracleDuoPoolStruct memory _params = params;
        return
            (_params.lp.get_virtual_price() * min(_coinPrice(_params.coin0Oracle, _params.coin0OracleDecimals), _coinPrice(_params.coin1Oracle, _params.coin1OracleDecimals))) /
            10 ** 18;
    }

    /// @dev Internal function to get the minimum of two numbers
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return b;
        }
        return a;
    }
}
