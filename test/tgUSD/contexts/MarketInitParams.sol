// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./WStableContext.sol";

contract MarketInitParams is WStableContext {
    mapping(address => ParamsInitConvexCurveLPMarket) public cvxCurveLPMaps;
    mapping(address => ParamsInitConvexFxnLPMarket) public cvxFxnLPMaps;

    struct ParamsInitConvexCurveLPMarket {
        MarketInitSimplified marketInit;
        ICvxRewardToken cvxRewardToken;
        uint256 pid;
        uint256 socFeePercentage;
    }

    struct ParamsInitConvexFxnLPMarket {
        MarketInitSimplified marketInit;
        uint256 pid;
        uint256 socFeePercentage;
    }

    struct MarketInitSimplified {
        IERC20Metadata collat;
        uint256 maxLTV;
        uint256 maxMarketDebt;
        uint256 liquidationThreshold;
        uint256 minimumLoan;
        IERC20Metadata[] _rewardTokens;
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
                maxMarketDebt: 1_000_000 ether,
                _rewardTokens: _rewardsCrvCvx
            }),
            cvxRewardToken: AddrCvxRewardTokens.CRVUSD_USDC_LP,
            pid: PidCvxCrvBooster.CRVUSD_USDC_LP,
            socFeePercentage: 1_000
        });

        // Convex Curve - FRXETH-WETH
        cvxCurveLPMaps[address(AddrCurveStableLP.FRXETH_WETH)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                collat: AddrCurveStableLP.FRXETH_WETH,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether,
                _rewardTokens: _rewardsCrvCvx
            }),
            cvxRewardToken: AddrCvxRewardTokens.FRXETH_WETH_LP,
            pid: PidCvxCrvBooster.FRXETH_WETH_LP,
            socFeePercentage: 1_000
        });

        // Convex Curve - PXETH-WETH
        cvxCurveLPMaps[address(AddrCurveStableLP.PXETH_WETH)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                collat: AddrCurveStableLP.PXETH_WETH,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether,
                _rewardTokens: _rewardsCrvCvx
            }),
            cvxRewardToken: AddrCvxRewardTokens.PXETH_WETH_LP,
            pid: PidCvxCrvBooster.PXETH_WETH_LP,
            socFeePercentage: 1_000
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
                maxMarketDebt: 1_000_000 ether,
                _rewardTokens: _rewardsFxn
            }),
            pid: PidCvxFxnBooster.USDC_FXUSD_LP,
            socFeePercentage: 1_000
        });
    }
}
