// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IAggregatorStablePriceV3} from "../../../interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";

/// @title MorphoOracleAdapter
/// @author Tangent Finance
/// @notice Price adapter fetching the price of a token with Tangent Oracle. Returned using same signature as Chainlink
contract OracleMorphoAdapter {
    IAggregatorStablePriceV3 public immutable usgOracle = IAggregatorStablePriceV3(0x970b2F2cEc66F92dE81DAe6af363d1D135dD2F97);

    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        answer = int256(usgOracle.price());
    }
}
