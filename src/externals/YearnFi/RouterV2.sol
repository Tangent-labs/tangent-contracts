// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import {BaseHealthCheck, ERC20} from "./BaseHealthCheck.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ShareValueHelper, IYearnVaultV2} from "./ShareValueHelper.sol";

contract RouterV2 is BaseHealthCheck {
    using SafeERC20 for ERC20;

    /// @notice The V2 yVault we are routing this strategy to.
    IYearnVaultV2 public immutable V2_VAULT;

    // no reason to deposit less than this, and helps us avoid any weird reverts from depositing 1 wei
    uint256 internal constant DUST = 1e6;

    /// @notice Max percentage loss we will take on withdrawals, in basis points. Default setting is zero.
    uint256 public maxLoss;

    ///@notice Mapping of addresses that are allowed to deposit.
    mapping(address depositor => bool isAllowed) public allowed;

    error WrongAsset();
    error WrongBPS();

    constructor(
        address _asset,
        string memory _name,
        address _v2Vault
    ) BaseHealthCheck(_asset, _name) {
        V2_VAULT = IYearnVaultV2(_v2Vault);
        require(V2_VAULT.token() == _asset, WrongAsset());

        asset.forceApprove(_v2Vault, type(uint256).max);
    }

    /* ========== VIEWS ========== */

    /**
     * @notice Return the current loose balance of this strategies `asset`.
     */
    function balanceOfAsset() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /**
     * @notice Return the current balance of the strategies vault shares.
     */
    function balanceOfVault() public view returns (uint256) {
        return V2_VAULT.balanceOf(address(this));
    }

    /**
     * @notice The full value denominated in `asset` of the strategies vault
     *   tokens held in the contract.
     */
    function valueOfVault() public view returns (uint256) {
        return
            ShareValueHelper.sharesToAmount(
                address(V2_VAULT),
                balanceOfVault(),
                false
            );
    }

    /// @notice Balance of asset we will gain on our next report
    function claimableProfits() external view returns (uint256 profits) {
        uint256 assets = balanceOfAsset() + valueOfVault();
        uint256 debt = TokenizedStrategy.totalAssets();

        if (assets > debt) {
            unchecked {
                profits = assets - debt;
            }
        } else {
            profits = 0;
        }
    }

    /* ========== CORE STRATEGY FUNCTIONS ========== */

    function _deployFunds(uint256 _amount) internal override {
        if (_amount > DUST) {
            V2_VAULT.deposit(_amount);
        }
    }

    function _freeFunds(uint256 _amount) internal override {
        // check how many shares we need against what we have
        uint256 balance = balanceOfVault();
        uint256 shares;

        if (_amount == type(uint256).max) {
            shares = balance;
        } else {
            // use share value helper for improved precision and round up
            shares = ShareValueHelper.amountToShares(
                address(V2_VAULT),
                _amount,
                true
            );

            if (shares > balance) shares = balance;
        }

        // trying to withdraw 0 reverts
        if (shares > 0) {
            V2_VAULT.withdraw(shares, address(this), maxLoss);
        }
    }

    function _harvestAndReport()
        internal
        override
        returns (uint256 _totalAssets)
    {
        _totalAssets = balanceOfAsset() + valueOfVault();
    }

    function availableDepositLimit(
        address _depositor
    ) public view override returns (uint256 depositLimit) {
        // If the depositor is whitelisted, allow deposits.
        if (allowed[_depositor]) {
            uint256 limit = V2_VAULT.depositLimit();
            uint256 assets = V2_VAULT.totalAssets();

            if (limit > assets) {
                unchecked {
                    depositLimit = limit - assets;
                }
            }
        } else {
            return 0;
        }
    }

    function _emergencyWithdraw(uint256 _amount) internal override {
        _freeFunds(_amount);
    }

    /* ========== SETTERS ========== */

    /**
     * @notice Set the maximum loss we will accept (due to slippage or locked funds) on a vault withdrawal.
     * @dev Generally, this should be zero, and this function will only be used in special/emergency cases.
     * @param _maxLoss Max percentage loss we will take, in basis points (100% = 10_000).
     */
    function setMaxLoss(uint256 _maxLoss) external onlyManagement {
        require(_maxLoss <= 10_000, WrongBPS());
        maxLoss = _maxLoss;
    }

    /**
     * @notice Set or update an addresses whitelist status.
     * @param _address the address for which to change the whitelist status
     * @param _allowed the bool to set as whitelisted (true) or not (false)
     */
    function setAllowed(
        address _address,
        bool _allowed
    ) external onlyManagement {
        allowed[_address] = _allowed;
    }
}
