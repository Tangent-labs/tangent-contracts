// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IYearnVaultFactory} from "../../interfaces/externals/YearnFi/IYearnVaultFactory.sol";
import {IYearnV3Vault} from "../../interfaces/externals/YearnFi/IYearnV3Vault.sol";
import {IRouterV2, IYearnV2Registry} from "../../interfaces/externals/YearnFi/IRouterV2.sol";
import {RouterV2} from "../../externals/YearnFi/RouterV2.sol";
import {IYearnRoleManager} from "../../interfaces/externals/YearnFi/IYearnRoleManager.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title YearnCurveLPVaultFactory
/// @notice Permissionless, one-tx deployment of a Yearn V3 vault on a Curve LP with a single
///         Yearn RouterV2 strategy routing into the LP's Yearn V2 vault. One vault per LP.
///         Handoff to Yearn's RoleManager setup:
///         - vault: role manager is transferred to `roleManager`; Yearn's Daddy then calls
///           `roleManager.addNewVault(vault, category)`, which accepts it and sets Yearn's roles/accountant.
///         - strategy: management (pending), emergency admin and fee recipient = RoleManager's Brain,
///           keeper = RoleManager's Keeper. Brain must call `strategy.acceptManagement()`.
///         The factory keeps no roles on either.
contract YearnCurveLPVaultFactory is Ownable2Step {
    IYearnV2Registry public constant V2_REGISTRY = IYearnV2Registry(0xaF1f5e1c19cB68B30aAD73846eFfDf78a5863319);
    uint256 public constant MAX_DEBT = 1e29;
    uint256 public constant ALL_ROLES = 0x3fff;
    uint256 public constant PROFIT_UNLOCK = 4 days;

    /// @notice Yearn V3 vault factory used to deploy new vaults.
    IYearnVaultFactory public v3Factory = IYearnVaultFactory(0x311de24e48C360B9A7765E7aB7eCDBABCd27B134);
    /// @notice Yearn V3 RoleManager: future role manager of every vault, source of strategy roles.
    IYearnRoleManager public roleManager;

    mapping(address lp => address vault) public vaults;

    event NewVault(address indexed lp, address vault, address strategy);
    event V3FactoryChanged(address indexed newFactory);
    event RoleManagerChanged(address indexed newRoleManager);

    error WrongFactory();
    error WrongRoleManager();
    error VaultAlreadyExist();
    error NoV2Vault();
    error CannotRenounceOwnership();

    /// @param _owner Manages this factory's settings (two-step ownership).
    /// @param _roleManager Yearn V3 RoleManager.
    constructor(address _owner, IYearnRoleManager _roleManager) Ownable(_owner) {
        _setRoleManager(_roleManager);
    }

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
        IYearnRoleManager _roleManager = roleManager;
        address brain = _roleManager.getBrain();
        strategy.setKeeper(_roleManager.getKeeper());
        strategy.setPerformanceFeeRecipient(brain);
        strategy.setEmergencyAdmin(brain);
        strategy.setPendingManagement(brain);

        // Wire
        vault.add_strategy(address(strategy));
        vault.update_max_debt_for_strategy(address(strategy), MAX_DEBT);
        vault.set_auto_allocate(true);

        // Handoff: RoleManager.addNewVault accepts it and sets Yearn's roles
        vault.set_role(address(this), 0);
        vault.transfer_role_manager(address(_roleManager));

        emit NewVault(lp, address(vault), address(strategy));
    }

    function setV3Factory(IYearnVaultFactory newFactory) external onlyOwner {
        require(address(newFactory) != address(0), WrongFactory());
        v3Factory = newFactory;
        emit V3FactoryChanged(address(newFactory));
    }

    function setRoleManager(IYearnRoleManager newRoleManager) external onlyOwner {
        _setRoleManager(newRoleManager);
    }

    function _setRoleManager(IYearnRoleManager newRoleManager) internal {
        require(address(newRoleManager) != address(0), WrongRoleManager());
        roleManager = newRoleManager;
        emit RoleManagerChanged(address(newRoleManager));
    }

    /// @dev Disabled: the factory settings would become frozen forever.
    function renounceOwnership() public view override onlyOwner {
        revert CannotRenounceOwnership();
    }
}
