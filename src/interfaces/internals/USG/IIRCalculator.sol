// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct IRParams {
    /// @dev Flag to determine if a Market is HEC or LEC
    bool isHEC;
    /// @dev Minimum IR reached at pMax.
    ///      1_000 <=> 1% / 100_000 <=> 100%.
    uint24 rMin;
    /// @dev Maximum IR reached at pMin.
    ///      1_000 <=> 1% / 100_000 <=> 100%.
    uint32 rMax;
    /// @dev Minimum price of USG where rMax is reached.
    ///      980_000 <=> 0.98$ / 1_000_000 <=> 1$
    uint32 pMin;
    /// @dev Inflexion price of USG where IR starts to increases more significantly.
    ///      980_000 <=> 0.98$ / 1_000_000 <=> 1$
    uint32 pInf;
    /// @dev Maximum price of USG where IR increases more significantly.
    ///      980_000 <=> 0.98$ / 1_000_000 <=> 1$
    uint32 pMax;
    /// @dev Convexity of the curve before pInf
    ///      2_000 <=> 2 / 4_500 <=> 4.5
    uint32 a1;
    /// @dev Convexity of the curve after pInf
    ///      2_000 <=> 2 / 4_500 <=> 4.5
    uint32 a2;
    /// @dev Velocity of the transition between a1 and a2
    ///      It's an integer. 250 <=> 250
    uint32 k;
}

struct IRCheckpoint {
    uint216 ir;
    uint40 timestamp;
}
interface IIRCalculator {
    function initializeMarket(address market, IRParams calldata _irParam) external;

    function simulateIR(uint256 USGPrice, IRParams memory irParam) external view returns (uint256);

    function computeIRForMarket(address market) external returns (uint256);

    function checkpointIR(address market) external returns (uint256);

    function newDebtIndex(address market) external view returns (uint256);

    function irCheckpoints(address market) external view returns (uint216, uint40);

    function debtIndexes(address market) external view returns (uint256);

    function indexDelta(address market) external view returns (uint256);

    function mintableInterests() external view returns (uint256);

    function getIRParams(address market) external view returns (IRParams memory);

    function getIRCheckpoint(address market) external view returns (IRCheckpoint memory);
}
