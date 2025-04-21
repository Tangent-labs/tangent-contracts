// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../src/libs/Resources/ResourcesGlobal.sol";

import {Test} from "forge-std/Test.sol";

contract Labeliser is Test {
    function labelizeERC20() external {
        // Stablecoins
        vm.label(address(AddrClassicERC20.TOKEN_DAI), "DAI");
        vm.label(address(AddrClassicERC20.TOKEN_FRAX), "FRAX");
        vm.label(address(AddrClassicERC20.TOKEN_USDT), "USDT");
        vm.label(address(AddrClassicERC20.TOKEN_CRVUSD), "CRVUSD");
        vm.label(address(AddrClassicERC20.TOKEN_USDC), "USDC");
        vm.label(address(AddrClassicERC20.TOKEN_DOLA), "DOLA");
        vm.label(address(AddrClassicERC20.TOKEN_FXUSD), "FXUSD");
        vm.label(address(AddrClassicERC20.TOKEN_FRXUSD), "frxUSD");
        vm.label(address(AddrClassicERC20.TOKEN_USR), "USR");
        vm.label(address(AddrClassicERC20.TOKEN_STUSR), "stUSR");
        vm.label(address(AddrClassicERC20.TOKEN_USDE), "USDE");
        vm.label(address(AddrClassicERC20.TOKEN_GHO), "GHO");

        // Volatiles
        vm.label(address(AddrClassicERC20.TOKEN_CRV), "CRV");
        vm.label(address(AddrClassicERC20.TOKEN_CVX), "CVX");
        vm.label(address(AddrClassicERC20.TOKEN_FXN), "FXN");
        vm.label(address(AddrClassicERC20.TOKEN_RLP), "RLP");

        // ETH
        vm.label(address(AddrClassicERC20.TOKEN_WETH), "WETH");
        vm.label(address(AddrClassicERC20.TOKEN_FRXETH), "frxETH");
        vm.label(address(AddrClassicERC20.TOKEN_PXETH), "pxETH");

        // BTC
        vm.label(address(AddrClassicERC20.TOKEN_WBTC), "WBTC");
        vm.label(address(AddrClassicERC20.TOKEN_CBBTC), "cbBTC");
    }

    function labelizeERC4626() external {
        vm.label(address(AddrERC4626.S_DAI), "sDAI");
        vm.label(address(AddrERC4626.S_CRVUSD), "scrvUSD");
        vm.label(address(AddrERC4626.REWARD_HANDLER_SCRVUSD), "scrvUSD Reward Handler");
        vm.label(address(AddrERC4626.S_FRAX), "sFRAX");
        vm.label(address(AddrERC4626.S_DOLA), "sDOLA");
        vm.label(address(AddrERC4626.S_FRXUSD), "sfrxUSD");
        vm.label(address(AddrERC4626.S_USDE), "sUSDe");
        vm.label(address(AddrERC4626.WST_USR), "wstUSR");
    }

    function labeliseNewConvexCrvMarket(address collat, string calldata collatSymbol, address convexMarket, address cvxRewardToken) external {
        vm.label(collat, collatSymbol);
        vm.label(convexMarket, string.concat("Market CvxCrv ", collatSymbol));
        vm.label(cvxRewardToken, string.concat("CvxRewardToken ", collatSymbol));
    }

    function labeliseNewConvexFxnMarket(address collat, string calldata collatSymbol, address convexMarket, address stakingProxyVault) external {
        vm.label(collat, collatSymbol);
        vm.label(convexMarket, string.concat("Market CvxFxn ", collatSymbol));
        vm.label(stakingProxyVault, string.concat("StakingProxyVault ", collatSymbol));
    }

    function labeliseNewNoRewardsMarket(address collat, string calldata collatSymbol, address market) external {
        vm.label(collat, collatSymbol);
        vm.label(market, string.concat("Market ", collatSymbol));
    }
}
