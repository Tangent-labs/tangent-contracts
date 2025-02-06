// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPegKeeperRegulator {
    event AddPegKeeper(address indexed peg_keeper, address indexed pool, bool is_inverse);
    event RemovePegKeeper(address indexed peg_keeper);
    event WorstPriceThreshold(uint256 threshold);
    event PriceDeviation(uint256 price_deviation);
    event DebtParameters(uint256 alpha, uint256 beta);
    event SetAggregator(address indexed aggregator);
    event SetFeeReceiver(address indexed fee_receiver);
    event SetKilled(uint8 indexed is_killed, address indexed by);
    event SetAdmin(address indexed admin);
    event SetEmergencyAdmin(address indexed admin);

    struct PegKeeperInfo {
        address peg_keeper;
        address pool;
        bool is_inverse;
        bool include_index;
    }

    enum Killed {
        Provide, // 1
        Withdraw // 2
    }

    function MAX_LEN() external pure returns (uint256);
    function ONE() external pure returns (uint256);

    function worst_price_threshold() external view returns (uint256);
    function price_deviation() external view returns (uint256);
    function alpha() external view returns (uint256);
    function beta() external view returns (uint256);
    function STABLECOIN() external view returns (address);
    function aggregator() external view returns (address);
    function peg_keepers(uint256) external view returns (address peg_keeper, address pool, bool is_inverse, bool include_index);
    function peg_keeper_i(address) external view returns (uint256);
    function fee_receiver() external view returns (address);
    function is_killed() external view returns (Killed);
    function admin() external view returns (address);
    function emergency_admin() external view returns (address);

    function stablecoin() external view returns (address);
    function provide_allowed(address _pk) external view returns (uint256);
    function withdraw_allowed(address _pk) external view returns (uint256);
    function add_peg_keepers(address[] calldata _peg_keepers) external;
    function remove_peg_keepers(address[] calldata _peg_keepers) external;
    function set_worst_price_threshold(uint256 _threshold) external;
    function set_price_deviation(uint256 _deviation) external;
    function set_debt_parameters(uint256 _alpha, uint256 _beta) external;
    function set_aggregator(address _agg) external;
    function set_fee_receiver(address _fee_receiver) external;
    function set_killed(Killed _is_killed) external;
    function set_admin(address _admin) external;
    function set_emergency_admin(address _admin) external;
}
