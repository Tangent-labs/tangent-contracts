// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CurveLendSplitterToken.sol";

import {IgUSDCvx} from "../../interfaces/internals/IgUSDCvx.sol";
import {IscvUSD} from "../../interfaces/internals/IscvUSD.sol";
import {ILlamaLendVault} from "../../interfaces/externals/ILlamaLendVault.sol";

contract scvUSDCvx is CurveLendSplitterToken, IscvUSD {
    using SafeERC20 for IERC20;
    IgUSDCvx public gUSD;
    ILlamaLendVault public llamaVault;
    IERC20 public cvxRewardToken;

    error OnlySCVUSDCaller(address caller);

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CONSTRUCTOR & INITIALIZER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initialize function
    function initialize(
        string memory _name,
        string memory _symbol,
        ILendRewardSplitter _lendRewardSplitter,
        ILlamaLendVault _llamaVault,
        address _cvxRewardToken
    ) external initializer {
        __ERC20_init(_name, _symbol);
        _transferOwnership(msg.sender);

        lendRewardSplitter = _lendRewardSplitter;
        llamaVault = _llamaVault;
        cvxRewardToken = IERC20(_cvxRewardToken);

        IERC20 crvUsd = IERC20(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);
        rewardTokens.push(crvUsd);
        rewardData[crvUsd].lastUpdateTime = uint128(block.timestamp);
        rewardData[crvUsd].periodFinish = uint128(block.timestamp);
        fees.push(ICurveLendSplitterToken.Fees({processorFeePercentage: 1_000, daoFeePercentage: 2_000}));
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        EXTERNALS USER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Mint scvUSD, only callable during deposit process from _depositCVX
     * @param to        Receiver of the scvUSD
     * @param amount    Amount of scvUSD to mint
     */
    function mint(address to, uint256 amount) external verifyLendSplitterCaller returns (uint256) {
        /// @dev Mint will call _updateReward
        _mint(to, amount);
        return amount;
    }

    function getTotalStaked() external view returns (uint256) {
        cvxRewardToken.balanceOf(address(gUSD)) + llamaVault.balanceOf(address(gUSD));
    }

    function getStreamableShares() external view returns (uint256) {
        IgUSDCvx _gUSD = gUSD;
        ILlamaLendVault _llamaVault = llamaVault;
        return
            cvxRewardToken.balanceOf(address(_gUSD)) + _llamaVault.balanceOf(address(_gUSD)) - totalSupply() - _llamaVault.convertToShares(_gUSD.totalSupply());
    }

    /**
     * @notice Process the rewards for scvUSD
     * @dev Redeem the shares left by gUSD stakers in lendAsset.
     *      Anyone can trigger this function and will be incentivized by a processor fee.
     */
    function processRewards() external {
        IgUSDCvx _gUSD = gUSD;
        ILlamaLendVault _llamaVault = llamaVault;
        /// @dev We need to keep enough share to back the stableSupply and the assetPart of the govSupply, we withdraw the reward share from the gUSD
        _gUSD.claimSCVUSDRewards(
            cvxRewardToken.balanceOf(address(_gUSD)) + _llamaVault.balanceOf(address(_gUSD)) - totalSupply() - _llamaVault.convertToShares(gUSD.totalSupply()),
            _llamaVault
        );
        _processRewards();
    }

    function setGUSD(address _gUSD) external verifyLendSplitterCaller {
        gUSD = IgUSDCvx(_gUSD);
    }
}
