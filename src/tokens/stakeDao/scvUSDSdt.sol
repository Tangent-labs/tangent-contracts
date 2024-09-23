// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISdtLiquidityGauge} from "../../interfaces/externals/ISdtLiquidityGauge.sol";
import {ILlamaLendVault} from "../../interfaces/externals/ILlamaLendVault.sol";
import {IgUSDSdt} from "../../interfaces/internals/IgUSDSdt.sol";
import {ILendRewardSplitter} from "../../interfaces/internals/ILendRewardSplitter.sol";
import {ICurveLendSplitterToken} from "../../interfaces/internals/ICurveLendSplitterToken.sol";
import {IscvUSD} from "../../interfaces/internals/IscvUSD.sol";
import {CurveLendSplitterToken} from "../CurveLendSplitterToken.sol";
contract scvUSDSdt is CurveLendSplitterToken, IscvUSD {
    using SafeERC20 for IERC20;
    address public sdtGauge;
    ILlamaLendVault public llamaLendVault;
    IgUSDSdt public gUSD;

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
        address _lendRewardSplitter,
        address _sdtGauge,
        ILlamaLendVault _llamaLendVault
    ) external initializer {
        __ERC20_init(_name, _symbol);
        _transferOwnership(msg.sender);

        lendRewardSplitter = ILendRewardSplitter(_lendRewardSplitter);
        sdtGauge = _sdtGauge;
        llamaLendVault = _llamaLendVault;

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
     * @notice Process Stable Rewards (only for scvUSD)
     * @dev Claim rewards from the splitter share  and stream it for the holders of scvUSD.
     *   Anyone can trigger this function and will be incentivized by a processor fee.
     */
    function processRewards() external {
        IgUSDSdt _gUSD = gUSD;
        ILlamaLendVault _llamaLendVault = llamaLendVault;

        /// @dev We need to keep enough share to back the stableSupply and the assetPart of the govSupply, we withdraw the reward share from the gUSD
        _gUSD.claimSCVUSDRewards(
            IERC20(sdtGauge).balanceOf(address(_gUSD)) - totalSupply() - _llamaLendVault.convertToShares(_gUSD.totalSupply()),
            _llamaLendVault
        );

        _processRewards();
    }

    function setGUSD(address _gUSD) external verifyLendSplitterCaller {
        gUSD = IgUSDSdt(_gUSD);
    }
}
