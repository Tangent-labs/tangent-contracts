// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";

/// @title USGMorphoAdapter
/// @author Tangent Finance
/// @notice Price adapter fetching USG price from Oracle. Returned using same signature as Chainlink
contract USGMorphoAdapter {
    IPriceOracle public oracle;

    constructor(address _oracle) {
        oracle = IPriceOracle(_oracle);
    }

    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        answer = int256(oracle.latestAnswer(true));
    }
}
