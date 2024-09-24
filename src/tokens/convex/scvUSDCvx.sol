// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CurveLendSplitterToken.sol";

import {IgUSDCvx} from "../../interfaces/internals/IgUSDCvx.sol";
import {IscvUSD} from "../../interfaces/internals/IscvUSD.sol";
import {ILlamaLendVault} from "../../interfaces/externals/ILlamaLendVault.sol";

contract scvUSDCvx is CurveLendSplitterToken, IscvUSD {
    using SafeERC20 for IERC20;
    IgUSDCvx public gUSD;
    ILlamaLendVault public llamaLendVault;
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
        ILlamaLendVault _llamaLendVault,
        address _cvxRewardToken
    ) external initializer {
        __ERC20_init(_name, _symbol);
        _transferOwnership(msg.sender);

        lendRewardSplitter = _lendRewardSplitter;
        llamaLendVault = _llamaLendVault;
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

    function getTotalStaked() external view returns  (uint256) {
        cvxRewardToken.balanceOf(address(gUSD)) + llamaLendVault.balanceOf(address(gUSD));
    }

    /**
     * @notice Process Stable Rewards (only for scvUSD)
     * @dev Claim rewards from the splitter share  and stream it for the holders of scvUSD.
     *   Anyone can trigger this function and will be incentivized by a processor fee.
     */
    function processRewards() external {
        IgUSDCvx _gUSD = gUSD;
        ILlamaLendVault _llamaLendVault = llamaLendVault;
        /// @dev We need to keep enough share to back the stableSupply and the assetPart of the govSupply, we withdraw the reward share from the gUSD
        _gUSD.claimSCVUSDRewards(
            cvxRewardToken.balanceOf(address(_gUSD)) +
                _llamaLendVault.balanceOf(address(_gUSD)) -
                totalSupply() -
                _llamaLendVault.convertToAssets(_gUSD.totalSupply()),
            _llamaLendVault
        );
        _processRewards();
    }

    function setGUSD(address _gUSD) external verifyLendSplitterCaller {
        gUSD = IgUSDCvx(_gUSD);
    }
}
