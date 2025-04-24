// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../../interfaces/internals/tgUSD/IPriceOracle.sol";
import "../../../interfaces/externals/Pendle/IPendlePYLpOracle.sol";
import "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";

import "forge-std/console.sol";

/// @title OracleDuoPoolStable
/// @notice This contract provides price oracle functionality for a dual pool stablecoin setup.
contract OraclePTToken is IPriceOracle {
    IPendlePYLpOracle public constant oracle = IPendlePYLpOracle(0x9a9Fa8338dd5E5B2188006f1Cd2Ef26d921650C2);
    address public market;

    constructor(address _market) {
        market = _market;
    }

    /**
     * @notice Returns the number of decimals used by the oracle
     * @return The number of decimals (18)
     */
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /**
     * @notice Returns the latest price from the oracle
     * @return The price of the stable pool, adjusted to 18 decimals
     */
    function latestAnswer() external view returns (uint256) {
        oracle.getPtToAssetRate(market, 30);
        return oracle.getPtToSyRate(market, 30);
    }

    /**
     * @notice Returns the latest price from the oracle
     * @return The price of the stable pool, adjusted to 18 decimals
     */
    function cac() external view returns (uint256, uint256) {
        return (oracle.getPtToSyRate(market, 30), oracle.getPtToAssetRate(market, 30));
    }
}
