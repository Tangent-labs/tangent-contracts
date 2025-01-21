// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
interface ICrvUSDController {
    function factory() external pure returns (address);

    function amm() external pure returns (address);

    function collateral_token() external pure returns (address);

    function borrowed_token() external pure returns (address);

    function save_rate() external;

    function debt(address user) external view returns (uint256);

    function loan_exists(address user) external view returns (bool);

    function total_debt() external view returns (uint256);

    function max_borrowable(uint256 collateral, uint256 N) external view returns (uint256);

    function max_borrowable(uint256 collateral, uint256 N, uint256 current_debt) external view returns (uint256);

    function min_collateral(uint256 debt, uint256 N) external view returns (uint256);

    function calculate_debt_n1(uint256 collateral, uint256 debt, uint256 N) external view returns (int256);

    function create_loan(uint256 collateral, uint256 debt, uint256 N) external;

    // function create_loan_extended ( uint256 collateral, uint256 debt, uint256 N, address callbacker, uint256[] callback_args ) external;
    function add_collateral(uint256 collateral) external;

    function add_collateral(uint256 collateral, address _for) external;

    function remove_collateral(uint256 collateral) external;

    function remove_collateral(uint256 collateral, bool use_eth) external;

    function borrow_more(uint256 collateral, uint256 debt) external;

    //function borrow_more_extended ( uint256 collateral, uint256 debt, address callbacker, uint256[] callback_args ) external;
    function repay(uint256 _d_debt) external;

    function repay(uint256 _d_debt, address _for) external;

    function repay(uint256 _d_debt, address _for, int256 max_active_band) external;

    function repay(uint256 _d_debt, address _for, int256 max_active_band, bool use_eth) external;

    // function repay_extended ( address callbacker, uint256[] callback_args ) external;
    function health_calculator(address user, int256 d_collateral, int256 d_debt, bool full) external view returns (int256);

    function health_calculator(address user, int256 d_collateral, int256 d_debt, bool full, uint256 N) external view returns (int256);

    function liquidate(address user, uint256 min_x) external;

    function liquidate(address user, uint256 min_x, bool use_eth) external;

    // function liquidate_extended ( address user, uint256 min_x, uint256 frac, bool use_eth, address callbacker, uint256[] callback_args ) external;
    function tokens_to_liquidate(address user) external view returns (uint256);

    function tokens_to_liquidate(address user, uint256 frac) external view returns (uint256);

    function health(address user) external view returns (int256);

    function health(address user, bool full) external view returns (int256);

    // function users_to_liquidate (  ) external view returns ( tuple[] );
    // function users_to_liquidate ( uint256 _from ) external view returns ( tuple[] );
    //function users_to_liquidate ( uint256 _from, uint256 _limit ) external view returns ( tuple[] );
    function amm_price() external view returns (uint256);

    // function user_prices ( address user ) external view returns ( uint256[2] );
    //function user_state ( address user ) external view returns ( uint256[4] );
    function set_amm_fee(uint256 fee) external;

    function set_amm_admin_fee(uint256 fee) external;

    function set_monetary_policy(address monetary_policy) external;

    function set_borrowing_discounts(uint256 loan_discount, uint256 liquidation_discount) external;

    function set_callback(address cb) external;

    function admin_fees() external view returns (uint256);

    function collect_fees() external returns (uint256);

    function check_lock() external view returns (bool);

    function liquidation_discounts(address arg0) external view returns (uint256);

    function loans(uint256 arg0) external view returns (address);

    function loan_ix(address arg0) external view returns (uint256);

    function n_loans() external view returns (uint256);

    function minted() external view returns (uint256);

    function redeemed() external view returns (uint256);

    function monetary_policy() external view returns (address);

    function liquidation_discount() external view returns (uint256);

    function loan_discount() external view returns (uint256);
}
