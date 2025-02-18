// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAggregatorStablePriceV3 {
    event AddPricePair(uint256 indexed n, address indexed pool, bool is_inverse);
    event RemovePricePair(uint256 indexed n);
    event MovePricePair(uint256 indexed n_from, uint256 indexed n_to);
    event SetAdmin(address indexed admin);

    function MAX_PAIRS() external pure returns (uint256);
    function MIN_LIQUIDITY() external pure returns (uint256);
    function TVL_MA_TIME() external pure returns (uint256);

    function price_pairs(uint256) external view returns (address pool, bool is_inverse);
    function n_price_pairs() external view returns (uint256);
    function last_timestamp() external view returns (uint256);
    function last_tvl(uint256) external view returns (uint256);
    function last_price() external view returns (uint256);
    function admin() external view returns (address);

    function set_admin(address _admin) external;
    function sigma() external view returns (uint256);
    function stablecoin() external view returns (address);
    function add_price_pair(address _pool) external;
    function remove_price_pair(uint256 n) external;
    function ema_tvl() external view returns (uint256[] memory);
    function price() external view returns (uint256);
    function price_w() external returns (uint256);
}
