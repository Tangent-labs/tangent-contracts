// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SplitterToken.sol";

import {IgUSDCvx} from "../interfaces/internals/IgUSDCvx.sol";
import {IscvUSD} from "../interfaces/internals/IscvUSD.sol";
import {ILlamaVault} from "../interfaces/externals/ILlamaVault.sol";

contract scvUSDCvx is SplitterToken, IscvUSD {
    using SafeERC20 for IERC20;
    IgUSDCvx public gUSD;
    ILlamaVault public llamaVault;
    IERC20 public cvxRewardToken;
    address autoCompounder;

    error OnlyGUSDCaller(address caller);
    error CallerNotAutoCompounder(address caller);

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CONSTRUCTOR & INITIALIZER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initialize function
    function initialize(
        address _owner,
        string memory _name,
        string memory _symbol,
        ILendRewardSplitter _lendRewardSplitter,
        ILlamaVault _llamaVault,
        address _cvxRewardToken
    ) external initializer {
        __ERC20_init(_name, _symbol);
        _transferOwnership(_owner);

        lendRewardSplitter = _lendRewardSplitter;
        llamaVault = _llamaVault;
        cvxRewardToken = IERC20(_cvxRewardToken);

        IERC20 crvUsd = IERC20(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);
        rewardTokens.push(crvUsd);
        rewardData[crvUsd].lastUpdateTime = uint128(block.timestamp);
        rewardData[crvUsd].periodFinish = uint128(block.timestamp);
        fees.push(ISplitterToken.Fees({processorFeePercentage: 1_000, daoFeePercentage: 2_000}));
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        EXTERNALS USER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Mint scvUSD, only callable during deposit process from _depositCVX
     * @param to        Receiver of the scvUSD
     * @param amount    Amount of scvUSD to mint
     */
    function mintSplitter(address to, uint256 amount) external verifyLendSplitterCaller {
        /// @dev Mint will call _updateReward
        _mint(to, amount);
    }

    /**
     * @notice Mint scvUSD, only callable during deposit process from _depositCVX
     * @param amount    Amount of scvUSD to mint
     */
    function mintAutoCompound(uint256 amount) external {
        address _autoCompounder = autoCompounder;
        require(msg.sender == _autoCompounder, CallerNotAutoCompounder(msg.sender));
        /// @dev Mint will call _updateReward
        _mint(_autoCompounder, amount);
    }

    /**
     * @notice Burn staked token
     * @param from        Owner of the staked ERC20 token
     * @param amount      Amount to burn
     */
    function burn(address from, uint256 amount) external verifyLendSplitterCaller {
        require(amount <= balanceOf(from), CantBurnThatMuchFor(from));
        /// @dev Burn will call _updateReward
        _burn(from, amount);
    }

    /**
     * @notice Function called by s
     * @dev Claim rewards in lendAsset from gUSD stakers that rennounced to their rewards from IR.
     */
    function processRewards() external {
        /// @dev We need to keep enough share to back the stableSupply and the assetPart of the govSupply, we withdraw the reward share from the gUSD
        require(msg.sender == address(gUSD), OnlyGUSDCaller(msg.sender));
        _processRewards();
    }

    function setAutoCompoundAndGUSD(address _autoCompounder, address _gUSD) external verifyLendSplitterCaller {
        gUSD = IgUSDCvx(_gUSD);
        autoCompounder = _autoCompounder;
    }
}
