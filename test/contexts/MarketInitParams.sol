// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./WStableContext.sol";

contract MarketInitParams is WStableContext {
    mapping(address => ParamsInitConvexCurveLPMarket) public cvxCurveLPMaps;
    mapping(address => ParamsInitConvexFxnLPMarket) public cvxFxnLPMaps;
    mapping(address => MarketInitSimplified) public basicERC20Maps;
    mapping(address => ParamsInitCurveGaugeMarket) public curveGaugeMaps;
    mapping(address => ParamsInitStakeDaoVaultV2Market) public stakeDaoVaultV2Maps;

    struct ParamsInitConvexCurveLPMarket {
        MarketInitSimplified marketInit;
        ICvxRewardToken cvxRewardToken;
        uint256 pid;
    }

    struct ParamsInitConvexFxnLPMarket {
        MarketInitSimplified marketInit;
        uint256 pid;
    }

    struct ParamsInitCurveGaugeMarket {
        MarketInitSimplified marketInit;
        IGauge gaugeToken;
    }

    struct ParamsInitStakeDaoVaultV2Market {
        MarketInitSimplified marketInit;
        IStakeDaoVaultV2 vaultToken;
    }

    struct MarketInitSimplified {
        IERC20Metadata collat;
        uint256 maxLTV;
        uint256 maxMarketDebt;
        uint256 liquidationThreshold;
        uint256 liquidationFee;
        uint256 minimumLoan;
        string name;
    }

    constructor() {
        initConvexCurveParams();
        initConvexFxnParams();
        initBasicERC20Market();
        initCurveGaugeParams();
        initStakeDaoVaultV2Params();
    }

    function initConvexCurveParams() public {
        // Convex Curve - CRVUSD-USDC
        cvxCurveLPMaps[address(AddrCurveStableLP.USDC_crvUSD)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                name: "Convex CRV - crvUSD-USDC",
                collat: AddrCurveStableLP.USDC_crvUSD,
                maxLTV: 90_000,
                liquidationThreshold: 93_000,
                liquidationFee: 2_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            cvxRewardToken: AddrCvxRewardTokens.USDC_crvUSD_LP,
            pid: PidCvxCrvBooster.USDC_crvUSD_LP
        });

        // Convex Curve - CRVUSD-USDT
        cvxCurveLPMaps[address(AddrCurveStableLP.USDT_crvUSD)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                name: "Convex CRV - crvUSD-USDT",
                collat: AddrCurveStableLP.USDT_crvUSD,
                maxLTV: 90_000,
                liquidationThreshold: 93_000,
                liquidationFee: 2_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            cvxRewardToken: AddrCvxRewardTokens.USDT_crvUSD_LP,
            pid: PidCvxCrvBooster.USDT_crvUSD_LP
        });

        // Convex Curve - FRXETH-WETH
        cvxCurveLPMaps[address(AddrCurveStableLP.WETH_frxETH)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                name: "Convex CRV - frxETH-WETH",
                collat: AddrCurveStableLP.WETH_frxETH,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                liquidationFee: 2_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            cvxRewardToken: AddrCvxRewardTokens.WETH_frxETH_LP,
            pid: PidCvxCrvBooster.WETH_frxETH_LP
        });

        // Convex Curve - PXETH-WETH
        cvxCurveLPMaps[address(AddrCurveStableLP.WETH_pxETH)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                name: "Convex CRV - pxETH-WETH",
                collat: AddrCurveStableLP.WETH_pxETH,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                liquidationFee: 2_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            cvxRewardToken: AddrCvxRewardTokens.WETH_pxETH_LP,
            pid: PidCvxCrvBooster.WETH_pxETH_LP
        });

        // Convex Curve - ETH-stETH
        cvxCurveLPMaps[address(AddrCurveStableLP.ETH_stETH_LP)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                name: "Convex CRV - stETH-ETH",
                collat: AddrCurveStableLP.ETH_stETH_LP,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                liquidationFee: 2_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 100_000_000 ether
            }),
            cvxRewardToken: AddrCvxRewardTokens.ETH_stETH_LP,
            pid: PidCvxCrvBooster.ETH_stETH_LP
        });

        // Convex Curve - ETH-CVX
        cvxCurveLPMaps[address(AddrCryptoSwapLP.CVX_ETH_LP)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                name: "Convex CRV - CVX-ETH",
                collat: AddrCryptoSwapLP.CVX_ETH_LP,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                liquidationFee: 2_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            cvxRewardToken: AddrCvxRewardTokens.CVX_ETH_LP,
            pid: PidCvxCrvBooster.CVX_ETH_LP
        });

        // Convex Curve - scrvUSD/sDOLA
        cvxCurveLPMaps[address(AddrCurveStableLP.scrvUSD_sDOLA)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                name: "Convex CRV - scrvUSD-sDOLA",
                collat: AddrCurveStableLP.scrvUSD_sDOLA,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                liquidationFee: 2_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            cvxRewardToken: AddrCvxRewardTokens.scrvUSD_sDOLA_LP,
            pid: PidCvxCrvBooster.scrvUSD_sDOLA_LP
        });

        // Convex Curve - TriCrypto USDC
        cvxCurveLPMaps[address(AddrCryptoSwapLP.USDC_WBTC_ETH)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                name: "Convex CRV - USDC-WBTC-ETH",
                collat: AddrCryptoSwapLP.USDC_WBTC_ETH,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                liquidationFee: 2_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            cvxRewardToken: AddrCvxRewardTokens.USDC_WBTC_WETH,
            pid: PidCvxCrvBooster.USDC_WBTC_WETH
        });

        /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
            LP without CRV inflation that are not yet on Convex
          =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

        // Convex Curve - sDAI/sUSDe
        cvxCurveLPMaps[address(AddrCurveStableLP.sDAI_sUSDe)] = ParamsInitConvexCurveLPMarket({
            marketInit: MarketInitSimplified({
                name: "Convex CRV - sDAI-sUSDe",
                collat: AddrCurveStableLP.sDAI_sUSDe,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                liquidationFee: 2_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            cvxRewardToken: ICvxRewardToken(address(0)),
            pid: 0
        });
    }

    function initConvexFxnParams() public {
        // Convex FXN - USDC_FXUSD
        cvxFxnLPMaps[address(AddrCurveStableLP.USDC_fxUSD)] = ParamsInitConvexFxnLPMarket({
            marketInit: MarketInitSimplified({
                name: "Convex FXN - fxUSD-USDC",
                collat: AddrCurveStableLP.USDC_fxUSD,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                liquidationFee: 2_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            pid: PidCvxFxnBooster.USDC_fxUSD_LP
        });
    }

    function initCurveGaugeParams() public {
        // Gauge - PYUSD-USDC
        curveGaugeMaps[address(AddrCurveStableLP.PYUSD_USDC)] = ParamsInitCurveGaugeMarket({
            marketInit: MarketInitSimplified({
                name: "CurveGauge - PYUSD-USDC",
                collat: AddrCurveStableLP.PYUSD_USDC,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                liquidationFee: 2_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            gaugeToken: AddrCurveGauge.PYUSD_USDC
        });

        // Gauge - RLUSD-USDC
        curveGaugeMaps[address(AddrCurveStableLP.RLUSD_USDC)] = ParamsInitCurveGaugeMarket({
            marketInit: MarketInitSimplified({
                name: "CurveGauge - RLUSD-USDC",
                collat: AddrCurveStableLP.RLUSD_USDC,
                maxLTV: 85_000,
                liquidationThreshold: 93_000,
                liquidationFee: 2_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            gaugeToken: AddrCurveGauge.RLUSD_USDC
        });
    }

    function initStakeDaoVaultV2Params() public {
        // Pendle - sUSDe_07_05_26
        basicERC20Maps[address(AddrPTPendle.sUSDe_07_05_26)] = MarketInitSimplified({
            name: "Pendle - sUSDe_07_05_26",
            collat: AddrPTPendle.sUSDe_07_05_26,
            maxLTV: 85_000,
            liquidationThreshold: 93_000,
            liquidationFee: 2_000,
            minimumLoan: 3_000 ether,
            maxMarketDebt: 1_000_000 ether
        });
        // Pendle - USDe_07_05_26
        basicERC20Maps[address(AddrPTPendle.USDe_07_05_26)] = MarketInitSimplified({
            name: "Pendle - USDe_07_05_26",
            collat: AddrPTPendle.USDe_07_05_26,
            maxLTV: 85_000,
            liquidationThreshold: 93_000,
            liquidationFee: 2_000,
            minimumLoan: 3_000 ether,
            maxMarketDebt: 1_000_000 ether
        });
        // StakeDao - CRVUSD-USDC
        stakeDaoVaultV2Maps[address(AddrCurveStableLP.USDC_crvUSD)] = ParamsInitStakeDaoVaultV2Market({
            marketInit: MarketInitSimplified({
                name: "StakeDao - crvUSD-USDC",
                collat: AddrCurveStableLP.USDC_crvUSD,
                maxLTV: 90_000,
                liquidationThreshold: 93_000,
                liquidationFee: 2_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            vaultToken: AddrStakeDaoVaultV2.USDC_crvUSD_LP
        });

        // StakeDao - CRVUSD-USDT
        stakeDaoVaultV2Maps[address(AddrCurveStableLP.USDT_crvUSD)] = ParamsInitStakeDaoVaultV2Market({
            marketInit: MarketInitSimplified({
                name: "StakeDao - crvUSD-USDT",
                collat: AddrCurveStableLP.USDT_crvUSD,
                maxLTV: 90_000,
                liquidationThreshold: 93_000,
                liquidationFee: 2_000,
                minimumLoan: 3_000 ether,
                maxMarketDebt: 1_000_000 ether
            }),
            vaultToken: AddrStakeDaoVaultV2.USDT_crvUSD_LP
        });
    }

    function initBasicERC20Market() public {
        // Pendle - wstUSR_29_01_26
        basicERC20Maps[address(AddrPTPendle.wstUSR_29_01_26)] = MarketInitSimplified({
            name: "Pendle - wstUSR 29/01/26",
            collat: AddrPTPendle.wstUSR_29_01_26,
            maxLTV: 85_000,
            liquidationThreshold: 93_000,
            liquidationFee: 2_000,
            minimumLoan: 3_000 ether,
            maxMarketDebt: 1_000_000 ether
        });

        // LP Curve - sUSDS/USDT
        basicERC20Maps[address(AddrCurveStableLP.sUSDS_USDT)] = MarketInitSimplified({
            name: "Convex CRV - sUSDS-USDT",
            collat: AddrCurveStableLP.sUSDS_USDT,
            maxLTV: 85_000,
            liquidationThreshold: 93_000,
            liquidationFee: 2_000,
            minimumLoan: 3_000 ether,
            maxMarketDebt: 1_000_000 ether
        });

        // LP Curve - sUSDS/USDT
        basicERC20Maps[address(AddrCurveStableLP.sDAI_sUSDe)] = MarketInitSimplified({
            name: "Convex CRV - sDAI-sUSDe",
            collat: AddrCurveStableLP.sDAI_sUSDe,
            maxLTV: 85_000,
            liquidationThreshold: 93_000,
            liquidationFee: 2_000,
            minimumLoan: 3_000 ether,
            maxMarketDebt: 1_000_000 ether
        });

        // Pendle - eUSDe_29_05_25
        basicERC20Maps[address(AddrPTPendle.eUSDe_29_05_25)] = MarketInitSimplified({
            name: "Pendle - eUSDe 05/29/25",
            collat: AddrPTPendle.eUSDe_29_05_25,
            maxLTV: 85_000,
            liquidationThreshold: 93_000,
            liquidationFee: 2_000,
            minimumLoan: 3_000 ether,
            maxMarketDebt: 1_000_000 ether
        });

        // Pendle - sUSDe_31_07_25
        basicERC20Maps[address(AddrPTPendle.sUSDe_31_07_25)] = MarketInitSimplified({
            name: "Pendle - sUSDe 07/31/25",
            collat: AddrPTPendle.sUSDe_31_07_25,
            maxLTV: 85_000,
            liquidationThreshold: 93_000,
            liquidationFee: 2_000,
            minimumLoan: 3_000 ether,
            maxMarketDebt: 1_000_000 ether
        });

        // Pendle - sUSDe_25_09_25
        basicERC20Maps[address(AddrPTPendle.sUSDe_25_09_25)] = MarketInitSimplified({
            name: "Pendle - sUSDe 09/25/25",
            collat: AddrPTPendle.sUSDe_25_09_25,
            maxLTV: 85_000,
            liquidationThreshold: 93_000,
            liquidationFee: 2_000,
            minimumLoan: 3_000 ether,
            maxMarketDebt: 1_000_000 ether
        });

        // Pendle - sUSDe_31_07_25
        basicERC20Maps[address(AddrPTPendle.USDe_25_09_25)] = MarketInitSimplified({
            name: "Pendle - sUSDe 09/25/25",
            collat: AddrPTPendle.USDe_25_09_25,
            maxLTV: 85_000,
            liquidationThreshold: 93_000,
            liquidationFee: 2_000,
            minimumLoan: 3_000 ether,
            maxMarketDebt: 1_000_000 ether
        });

        // Pendle - USDe_27_11_25
        basicERC20Maps[address(AddrPTPendle.USDe_27_11_25)] = MarketInitSimplified({
            name: "Pendle - USDe 11/27/25",
            collat: AddrPTPendle.USDe_27_11_25,
            maxLTV: 85_000,
            liquidationThreshold: 93_000,
            liquidationFee: 2_000,
            minimumLoan: 3_000 ether,
            maxMarketDebt: 1_000_000 ether
        });

        // Pendle - sUSDe_27_11_25
        basicERC20Maps[address(AddrPTPendle.sUSDe_27_11_25)] = MarketInitSimplified({
            name: "Pendle - sUSDe 11/27/25",
            collat: AddrPTPendle.sUSDe_27_11_25,
            maxLTV: 85_000,
            liquidationThreshold: 93_000,
            liquidationFee: 2_000,
            minimumLoan: 3_000 ether,
            maxMarketDebt: 1_000_000 ether
        });
    }
}
