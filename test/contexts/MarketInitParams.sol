// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./WStableContext.sol";

contract MarketInitParams is WStableContext {
    mapping(address => ParamsInitConvexCurveLPMarket) public cvxCurveLPMaps;
    mapping(address => ParamsInitConvexFxnLPMarket) public cvxFxnLPMaps;
    mapping(address => MarketInitSimplified) public noSociabilizationMaps;

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
    }

    constructor() {
        initConvexCurveParams();
        initConvexFxnParams();
    }

    function initConvexCurveParams() public {
        // Convex Curve - CRVUSD-USDC
        cvxCurveLPMaps[address(AddrCurveStableLP.USDC_crvUSD)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                collat: AddrCurveStableLP.USDC_crvUSD,
                maxLTV: 90_000,
                liquidationThreshold: 93_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            cvxRewardToken: AddrCvxRewardTokens.USDC_crvUSD_LP,
            pid: PidCvxCrvBooster.USDC_crvUSD_LP,
            socFeePercentage: 1_000
        });

        // Convex Curve - CRVUSD-USDT
        cvxCurveLPMaps[address(AddrCurveStableLP.USDT_crvUSD)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                collat: AddrCurveStableLP.USDT_crvUSD,
                maxLTV: 90_000,
                liquidationThreshold: 93_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            cvxRewardToken: AddrCvxRewardTokens.USDT_crvUSD_LP,
            pid: PidCvxCrvBooster.USDT_crvUSD_LP,
            socFeePercentage: 1_000
        });

        // Convex Curve - FRXETH-WETH
        cvxCurveLPMaps[address(AddrCurveStableLP.WETH_frxETH)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                collat: AddrCurveStableLP.WETH_frxETH,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            cvxRewardToken: AddrCvxRewardTokens.WETH_frxETH_LP,
            pid: PidCvxCrvBooster.WETH_frxETH_LP,
            socFeePercentage: 1_000
        });

        // Convex Curve - PXETH-WETH
        cvxCurveLPMaps[address(AddrCurveStableLP.WETH_pxETH)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                collat: AddrCurveStableLP.WETH_pxETH,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            cvxRewardToken: AddrCvxRewardTokens.WETH_pxETH_LP,
            pid: PidCvxCrvBooster.WETH_pxETH_LP,
            socFeePercentage: 1_000
        });
    }

    function initConvexFxnParams() public {
        // Convex FXN - USDC_FXUSD
        cvxFxnLPMaps[address(AddrCurveStableLP.USDC_fxUSD)] = ParamsInitConvexFxnLPMarket({
            marketInit: MarketInitSimplified({
                collat: AddrCurveStableLP.USDC_fxUSD,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            pid: PidCvxFxnBooster.USDC_fxUSD_LP,
            socFeePercentage: 1_000
        });
    }

    function initMarketNoSociabilization() public {
        // Pendle - eUSDe_29_05_25
        noSociabilizationMaps[address(AddrPTPendle.eUSDe_29_05_25)] = MarketInitSimplified({
            collat: AddrPTPendle.eUSDe_29_05_25,
            maxLTV: 85_000,
            liquidationThreshold: 93_000,
            minimumLoan: 3_000 ether,
            maxMarketDebt: 1_000_000 ether
        });

        // Pendle - sUSDe_31_07_25
        noSociabilizationMaps[address(AddrPTPendle.sUSDe_31_07_25)] = MarketInitSimplified({
            collat: AddrPTPendle.sUSDe_31_07_25,
            maxLTV: 85_000,
            liquidationThreshold: 93_000,
            minimumLoan: 3_000 ether,
            maxMarketDebt: 1_000_000 ether
        });
    }
}
