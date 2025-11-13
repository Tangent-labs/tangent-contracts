// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
interface IYearnVaultFactory {
    function deploy_new_vault(address asset, string memory name, string memory symbol, address role_manager, uint256 profit_max_unlock_time) external returns (address);
    function vault_original() external view returns (address);
    function apiVersion() external view returns (string memory);
    function protocol_fee_config() external view returns (uint16, address);
    function protocol_fee_config(address vault) external view returns (uint16, address);
    function use_custom_protocol_fee(address vault) external view returns (bool);
    function set_protocol_fee_bps(uint16 new_protocol_fee_bps) external;
    function set_protocol_fee_recipient(address new_protocol_fee_recipient) external;
    function set_custom_protocol_fee_bps(address vault, uint16 new_custom_protocol_fee) external;
    function remove_custom_protocol_fee(address vault) external;
    function shutdown_factory() external;
    function transferGovernance(address new_governance) external;
    function acceptGovernance() external;
    function shutdown() external view returns (bool);
    function governance() external view returns (address);
    function pendingGovernance() external view returns (address);
    function name() external view returns (string memory);

    event NewVault(address indexed newVault, address indexed asset);
}
