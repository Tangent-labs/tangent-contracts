// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {ISdtLiquidityGauge} from "../../interfaces/externals/ISdtLiquidityGauge.sol";
import "../CurveLendSplitterToken.sol";

contract gUSDSdt is CurveLendSplitterToken {
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
    function initialize(string memory _name, string memory _symbol, address _lendRewardSplitter, address _liquidityGauge) external initializer {
        __ERC20_init(_name, _symbol);
        _transferOwnership(msg.sender);
        lendRewardSplitter = ILendRewardSplitter(_lendRewardSplitter);
        liquidityGauge = ISdtLiquidityGauge(_liquidityGauge);

        IERC20 crv = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
        rewardTokens.push(crv);
        rewardData[crv].lastUpdateTime = uint128(block.timestamp);
        rewardData[crv].periodFinish = uint128(block.timestamp);
        fees.push(ICurveLendSplitterToken.Fees({processorFeePercentage: 1_000, daoFeePercentage: 2_000}));

        IERC20 cvx = IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
        rewardTokens.push(cvx);
        rewardData[cvx].lastUpdateTime = uint128(block.timestamp);
        rewardData[cvx].periodFinish = uint128(block.timestamp);
        fees.push(ICurveLendSplitterToken.Fees({processorFeePercentage: 1_000, daoFeePercentage: 2_000}));
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        EXTERNALS USER
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Process Governance Rewards (only for gUSD)
     * @dev Claim rewards from the splitter and stream it for the holders of gUSD.
     *      Anyone can trigger this function and will be incentivized by a processor fee.
     */
    function processRewards() external {
        /// @dev Claim rewards on behalf of the splitter on this contract
        liquidityGauge.claim_rewards(address(lendRewardSplitter));

        _processRewards();
    }
}
