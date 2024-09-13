// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CurveLendSplitterToken.sol";

contract scvUSDCvx is CurveLendSplitterToken {
    using SafeERC20 for IERC20;

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CONSTRUCTOR & INITIALIZER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initialize function
    function initialize(string memory _name, string memory _symbol, ILendRewardSplitter _lendRewardSplitter) external initializer {
        __ERC20_init(_name, _symbol);
        _transferOwnership(msg.sender);

        lendRewardSplitter = _lendRewardSplitter;

        IERC20 crvUsd = IERC20(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);
        rewardTokens.push(crvUsd);
        rewardData[crvUsd].lastUpdateTime = uint128(block.timestamp);
        rewardData[crvUsd].periodFinish = uint128(block.timestamp);
        fees.push(ICurveLendSplitterToken.Fees({processorFeePercentage: 1_000, daoFeePercentage: 2_000}));
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        EXTERNALS USER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    //     /**
    //      * @notice Process Stable Rewards (only for scvUSD)
    //      * @dev Claim rewards from the splitter share  and stream it for the holders of scvUSD.
    //      *   Anyone can trigger this function and will be incentivized by a processor fee.
    //      */
    //     function processRewards(address _market) external returns (uint256 rewardToProcess) {
    //         ILendRewardSplitter _lendRewardSplitter = lendRewardSplitter;
    //         ISdtLiquidityGauge _sdtGauge = sdtGauge;

    //         /// @dev We need to keep enough share to back the stableSupply and the assetPart of the govSupply.
    //         uint256 rewardShare = _sdtGauge.balanceOf(address(_lendRewardSplitter)) - totalSupply() - llamaLendVault.convertToAssets(gUSD.totalSupply());
    //         /// @dev We withdraw the reward share from the splitter
    //         _lendRewardSplitter.withdrawScvUsdRewards(_market, rewardShare);

    //         _processRewards();
    //     }
    // }
}
