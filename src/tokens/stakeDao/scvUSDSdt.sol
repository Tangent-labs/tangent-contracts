// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {ISdtLiquidityGauge} from "../../interfaces/externals/ISdtLiquidityGauge.sol";
import "../CurveLendSplitterToken.sol";

contract scvUSDSdt is CurveLendSplitterToken {
    using SafeERC20 for IERC20;
    ISdtLiquidityGauge public liquidityGauge;

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        CONSTRUCTOR & INITIALIZER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initialize function
    function initialize(string memory _name, string memory _symbol, address _lendRewardSplitter) external initializer {
        __ERC20_init(_name, _symbol);
        _transferOwnership(msg.sender);
        // processorRewardsPercentage = 1_000; /// @dev TODO: TO CHANGE -> corresponds to 1%
        // daoFeesPercentage = 2_000; /// @dev TODO: TO CHANGE -> corresponds to 2%
        lendRewardSplitter = ILendRewardSplitter(_lendRewardSplitter);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        EXTERNALS USER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
}
