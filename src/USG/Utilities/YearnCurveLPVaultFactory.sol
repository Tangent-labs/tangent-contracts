// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IYearnVaultFactory} from "../../interfaces/externals/YearnFi/IYearnVaultFactory.sol";
import {IYearnV3Vault} from "../../interfaces/externals/YearnFi/IYearnV3Vault.sol";
import {IRouterV2, IYearnV2Registry} from "../../interfaces/externals/YearnFi/IRouterV2.sol";
import {RouterV2} from "../../externals/YearnFi/RouterV2.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title YearnCurveLPVaultFactory
/// @notice Permissionless, one-tx deployment of a Yearn V3 vault on a Curve LP with a single
///         Yearn RouterV2 strategy routing into the LP's Yearn V2 vault. One vault per LP.
///         Everything is handed to `owner()`, which must call `vault.accept_role_manager()` and
///         `strategy.acceptManagement()`. The factory keeps no vault roles.
contract YearnCurveLPVaultFactory is Ownable2Step {
    IYearnV2Registry public constant V2_REGISTRY = IYearnV2Registry(0xaF1f5e1c19cB68B30aAD73846eFfDf78a5863319);
    uint256 public constant MAX_DEBT = 1e29;
    uint256 public constant ALL_ROLES = 0x3fff;
    uint256 public constant PROFIT_UNLOCK = 4 days;

    /// @notice Yearn V3 vault factory used to deploy new vaults.
    IYearnVaultFactory public v3Factory = IYearnVaultFactory(0x311de24e48C360B9A7765E7aB7eCDBABCd27B134);

    mapping(address lp => address vault) public vaults;

    event NewVault(address indexed lp, address vault, address strategy);
    event V3FactoryChanged(address indexed newFactory);

    error WrongFactory();
    error VaultAlreadyExist();
    error NoV2Vault();
    error CannotRenounceOwnership();

    /// @param _owner Receives all roles of deployed vaults/strategies and manages this factory.
    ///        Ownership changes (two-step) only affect vaults deployed afterwards.
    constructor(address _owner) Ownable(_owner) {}

    function deploy(address lp, string calldata name, string calldata symbol)
        external
        returns (IYearnV3Vault vault, IRouterV2 strategy)
    {
        require(vaults[lp] == address(0), VaultAlreadyExist());
        address v2Vault = V2_REGISTRY.latestVault(lp);
        require(v2Vault != address(0), NoV2Vault());

        // Vault
        vault = IYearnV3Vault(v3Factory.deploy_new_vault(lp, name, symbol, address(this), PROFIT_UNLOCK));
        vaults[lp] = address(vault);
        vault.set_role(address(this), ALL_ROLES);
        vault.set_deposit_limit(MAX_DEBT);

        // Strategy (this factory is its initial management/keeper/feeRecipient)
        strategy = IRouterV2(address(new RouterV2(lp, "V2 Router", v2Vault)));
        strategy.setPerformanceFee(0);
        strategy.setProfitMaxUnlockTime(0);
        strategy.setAllowed(address(vault), true);
        address _admin = owner();
        strategy.setKeeper(_admin);
        strategy.setPerformanceFeeRecipient(_admin);
        strategy.setEmergencyAdmin(_admin);
        strategy.setPendingManagement(_admin);

        // Wire
        vault.add_strategy(address(strategy));
        vault.update_max_debt_for_strategy(address(strategy), MAX_DEBT);
        vault.set_auto_allocate(true);

        // Handoff
        vault.set_role(_admin, ALL_ROLES);
        vault.set_role(address(this), 0);
        vault.transfer_role_manager(_admin);

        emit NewVault(lp, address(vault), address(strategy));
    }

    function setV3Factory(IYearnVaultFactory newFactory) external onlyOwner {
        require(address(newFactory) != address(0), WrongFactory());
        v3Factory = newFactory;
        emit V3FactoryChanged(address(newFactory));
    }

    /// @dev Disabled: without an owner, new vaults' roles would be handed to address(0).
    function renounceOwnership() public view override onlyOwner {
        revert CannotRenounceOwnership();
    }
}
