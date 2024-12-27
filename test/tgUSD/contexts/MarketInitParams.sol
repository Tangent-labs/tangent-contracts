// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./TgStableContext.sol";

contract MarketInitParams is TgStableContext {
    mapping(address => ParamsInitConvexCurveLPMarket) public cvxCurveLPMaps;
    mapping(address => ParamsInitConvexFxnLPMarket) public cvxFxnLPMaps;

    struct ParamsInitConvexCurveLPMarket {
        MarketInitSimplified marketInit;
        IERC20Metadata[] rewards;
        ICvxRewardToken cvxRewardToken;
        uint256 pid;
    }

    struct ParamsInitConvexFxnLPMarket {
        MarketInitSimplified marketInit;
        IERC20Metadata[] rewards;
        uint256 pid;
    }

    struct MarketInitSimplified {
        IERC20Metadata collat;
        uint256 maxLTV;
        uint256 maxMarketDebt;
        uint256 liquidationThreshold;
        uint256 minimumLoan;
    }

    constructor() {
        initConvexCurveParams();
        initConvexFxnParams();
    }

    function initConvexCurveParams() public {
        IERC20Metadata[] memory _rewardsCrvCvx = Array.memoryIERC20([AddrClassicERC20.TOKEN_CRV, AddrClassicERC20.TOKEN_CVX]);

        // Convex Curve - CRVUSD-USDC
        cvxCurveLPMaps[address(AddrCurveStableLP.CRVUSD_USDC)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                collat: AddrCurveStableLP.CRVUSD_USDC,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            rewards: _rewardsCrvCvx,
            cvxRewardToken: AddrCvxRewardTokens.CRVUSD_USDC_LP,
            pid: PidCvxCrvBooster.CRVUSD_USDC_LP
        });

        // Convex Curve - FRXETH-WETH
        cvxCurveLPMaps[address(AddrCurveStableLP.FRXETH_WETH)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                collat: AddrCurveStableLP.FRXETH_WETH,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            rewards: _rewardsCrvCvx,
            cvxRewardToken: AddrCvxRewardTokens.FRXETH_WETH_LP,
            pid: PidCvxCrvBooster.FRXETH_WETH_LP
        });
    }

    function initConvexFxnParams() public {
        IERC20Metadata[] memory _rewardsFxn = Array.memoryIERC20([AddrClassicERC20.TOKEN_FXN, AddrClassicERC20.TOKEN_CRV, AddrClassicERC20.TOKEN_CVX]);

        // Convex FXN - USDC_FXUSD
        cvxFxnLPMaps[address(AddrCurveStableLP.USDC_FXUSD)] = ParamsInitConvexFxnLPMarket({
            marketInit: MarketInitSimplified({
                collat: AddrCurveStableLP.USDC_FXUSD,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            rewards: _rewardsFxn,
            pid: PidCvxFxnBooster.USDC_FXUSD_LP
        });
    }
}
