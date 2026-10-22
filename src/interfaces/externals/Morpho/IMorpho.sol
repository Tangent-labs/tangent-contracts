// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct MarketParams {
    address loanToken;
    address collateralToken;
    address oracle;
    address irm;
    uint256 lltv;
}

struct Position {
    uint256 supplyShares;
    uint128 borrowShares;
    uint128 collateral;
}

struct Market {
    uint128 totalSupplyAssets;
    uint128 totalSupplyShares;
    uint128 totalBorrowAssets;
    uint128 totalBorrowShares;
    uint128 lastUpdate;
    uint128 fee;
}

/// Trimmed from morpho-org/morpho-blue IMorpho: the subset used against the
/// singleton 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb (markets are keyed by
/// id = keccak256(abi.encode(MarketParams))).
interface IMorpho {
    event CreateMarket(bytes32 indexed id, MarketParams marketParams);
    event Supply(bytes32 indexed id, address indexed caller, address indexed onBehalf, uint256 assets, uint256 shares);
    event SupplyCollateral(bytes32 indexed id, address indexed caller, address indexed onBehalf, uint256 assets);
    event WithdrawCollateral(bytes32 indexed id, address caller, address indexed onBehalf, address indexed receiver, uint256 assets);
    event Borrow(bytes32 indexed id, address caller, address indexed onBehalf, address indexed receiver, uint256 assets, uint256 shares);
    event Repay(bytes32 indexed id, address indexed caller, address indexed onBehalf, uint256 assets, uint256 shares);
    event Liquidate(
        bytes32 indexed id,
        address indexed caller,
        address indexed borrower,
        uint256 repaidAssets,
        uint256 repaidShares,
        uint256 seizedAssets,
        uint256 badDebtAssets,
        uint256 badDebtShares
    );
    event AccrueInterest(bytes32 indexed id, uint256 prevBorrowRate, uint256 interest, uint256 feeShares);

    function createMarket(MarketParams memory marketParams) external;

    function supply(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256 assetsSupplied, uint256 sharesSupplied);

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data) external;

    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver) external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256 assetsBorrowed, uint256 sharesBorrowed);

    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256 assetsRepaid, uint256 sharesRepaid);

    function liquidate(
        MarketParams memory marketParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes memory data
    ) external returns (uint256 seized, uint256 repaid);

    function accrueInterest(MarketParams memory marketParams) external;

    function market(bytes32 id) external view returns (Market memory m);

    function position(bytes32 id, address user) external view returns (Position memory p);

    function isIrmEnabled(address irm) external view returns (bool);

    function isLltvEnabled(uint256 lltv) external view returns (bool);
}
