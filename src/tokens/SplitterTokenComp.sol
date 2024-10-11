// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILendRewardSplitter} from "../interfaces/internals/ILendRewardSplitter.sol";
import {ISplitterToken} from "../interfaces/internals/ISplitterToken.sol";
import {ICommonStruct} from "../interfaces/internals/ICommonStruct.sol";
import {ILlamaVault} from "../interfaces/externals/ILlamaVault.sol";
import {IscvUSD} from "../interfaces/internals/IscvUSD.sol";

import {Errors} from "../libs/Errors.sol";

import "forge-std/console.sol"; //TODO: to remove

contract SplitterTokenComp is ERC4626Upgradeable, OwnableUpgradeable {
    uint256 constant MAX_UINT = uint256(int256(-1));

    ILendRewardSplitter public splitter;

    IERC20 public lendAsset;

    ILlamaVault public llamaVault;

    error NotLendRewardSplitter(address _address);

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        EXTERNALS USER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CONSTRUCTOR & INITIALIZER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier verifyLendSplitterCaller() {
        /// @dev Requires the lendRewardSplitter is the caller of this function
        require(msg.sender == address(splitter), NotLendRewardSplitter(msg.sender));
        _;
    }

    /// @notice initialize function
    function initialize(address _owner, IERC20 _asset, ILendRewardSplitter _splitter, ILlamaVault _llamaVault, IERC20 _lendAsset) external initializer {
        __ERC4626_init(_asset);
        __ERC20_init("Vault Compound", "CVP");
        splitter = _splitter;
        lendAsset = _lendAsset;
        llamaVault = _llamaVault;

        lendAsset.approve(address(splitter), MAX_UINT);

        _transferOwnership(_owner);
    }

    function indexation() external onlyOwner {
        ILendRewardSplitter _splitter = splitter;
        _splitter.claimSimple(asset());
        _splitter.depositSCVUSD(llamaVault, ILendRewardSplitter.CVX_TOKEN_TYPE.LendAsset, lendAsset.balanceOf(address(this)), false, true);
    }

    function mintSplitter(address receiver, uint256 assets, IscvUSD scvUSD) external verifyLendSplitterCaller returns (uint256) {
        uint256 shares = previewDeposit(assets);
        /// @dev AutoCompound branch so we mint scvUSD on the vault
        scvUSD.mintAutoCompound(assets);
        _mint(receiver, shares);
        return shares;
    }

    function burnSplitter(address from, uint256 shares) external virtual verifyLendSplitterCaller returns (uint256) {
        uint256 assets = convertToAssets(shares);
        _burn(from, shares);
        return assets;
    }

    function _decimalsOffset() internal pure override returns (uint8) {
        return 0;
    }

    function convertFromAutoCompToLendAsset(uint256 shares) external view returns (uint256) {
        return llamaVault.convertToAssets(convertToAssets(shares));
    }

    function convertFromLendAssetToAutoComp(uint256 lendAssetAmount) external view returns (uint256) {
        return convertToShares(llamaVault.convertToShares(lendAssetAmount));
    }
}
