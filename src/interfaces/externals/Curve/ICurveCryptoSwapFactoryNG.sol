// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
interface ICurveCryptoSwapFactoryNG {
    function initialise_ownership(address _fee_receiver, address _admin) external;
    function deploy_pool(
        string memory _name,
        string memory _symbol,
        address[2] memory _coins,
        uint256 implementation_id,
        uint256 A,
        uint256 gamma,
        uint256 mid_fee,
        uint256 out_fee,
        uint256 fee_gamma,
        uint256 allowed_extra_profit,
        uint256 adjustment_step,
        uint256 ma_exp_time,
        uint256 initial_price
    ) external returns (address);
    function deploy_gauge(address _pool) external returns (address);
    function set_fee_receiver(address _fee_receiver) external;
    function set_pool_implementation(address _pool_implementation, uint256 _implementation_index) external;
    function set_gauge_implementation(address _gauge_implementation) external;
    function set_views_implementation(address _views_implementation) external;
    function set_math_implementation(address _math_implementation) external;
    function commit_transfer_ownership(address _addr) external;
    function accept_transfer_ownership() external;
    function find_pool_for_coins(address _from, address _to) external view returns (address);
    function find_pool_for_coins(address _from, address _to, uint256 i) external view returns (address);
    function pool_count() external view returns (uint256);
    function get_coins(address _pool) external view returns (address[2] memory);
    function get_decimals(address _pool) external view returns (uint256[2] memory);
    function get_balances(address _pool) external view returns (uint256[2] memory);
    function get_coin_indices(address _pool, address _from, address _to) external view returns (uint256, uint256);
    function get_gauge(address _pool) external view returns (address);
    function get_market_counts(address coin_a, address coin_b) external view returns (uint256);
    function admin() external view returns (address);
    function future_admin() external view returns (address);
    function fee_receiver() external view returns (address);
    function pool_implementations(uint256 arg0) external view returns (address);
    function gauge_implementation() external view returns (address);
    function views_implementation() external view returns (address);
    function math_implementation() external view returns (address);
    function pool_list(uint256 arg0) external view returns (address);
}
