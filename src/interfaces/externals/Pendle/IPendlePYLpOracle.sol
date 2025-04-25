// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPendlePYLpOracle {
    function BLOCK_CYCLE_DENOMINATOR() external view returns (uint16);
    function blockCycleNumerator() external view returns (uint16);
    function claimOwnership() external;
    function getLpToAssetRate(address market, uint32 duration) external view returns (uint256);
    function getLpToSyRate(address market, uint32 duration) external view returns (uint256);
    function getOracleState(address market, uint32 duration) external view returns (bool increaseCardinalityRequired, uint16 cardinalityRequired, bool oldestObservationSatisfied);
    function getPtToAssetRate(address market, uint32 duration) external view returns (uint256);
    function getPtToSyRate(address market, uint32 duration) external view returns (uint256);
    function getYtToAssetRate(address market, uint32 duration) external view returns (uint256);
    function getYtToSyRate(address market, uint32 duration) external view returns (uint256);
    function initialize(uint16 _blockCycleNumerator) external;
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function setBlockCycleNumerator(uint16 newBlockCycleNumerator) external;
    function transferOwnership(address newOwner, bool direct, bool renounce) external;
}
