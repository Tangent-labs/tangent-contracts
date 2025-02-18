pragma solidity ^0.8.0;

interface IPegKeeperV2 {
    function factory() external view returns (address);
    function pegged() external view returns (address);
    function pool() external view returns (address);
    function calc_profit() external view returns (uint256);
    function estimate_caller_profit() external view returns (uint256);
    function update(address _beneficiary) external returns (uint256);
    function withdraw_profit() external returns (uint256);
    function set_new_action_delay(uint256 _new_action_delay) external;
    function set_new_caller_share(uint256 _new_caller_share) external;
    function set_new_regulator(address _new_regulator) external;
    function commit_new_admin(address _new_admin) external;
    function apply_new_admin() external;
}
