// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../src/libs/Resources/ResourcesGlobal.sol";

import {Test} from "forge-std/Test.sol";

contract Labeliser is Test {
    function labelizeERC20() external {
        // Stablecoins
        vm.label(address(AddrClassicERC20.DAI), "DAI");
        vm.label(address(AddrClassicERC20.FRAX), "FRAX");
        vm.label(address(AddrClassicERC20.USDT), "USDT");
        vm.label(address(AddrClassicERC20.crvUSD), "CRVUSD");
        vm.label(address(AddrClassicERC20.USDC), "USDC");
        vm.label(address(AddrClassicERC20.DOLA), "DOLA");
        vm.label(address(AddrClassicERC20.fxUSD), "fxUSD");
        vm.label(address(AddrClassicERC20.frxUSD), "frxUSD");
        vm.label(address(AddrClassicERC20.USR), "USR");
        vm.label(address(AddrClassicERC20.stUSR), "stUSR");
        vm.label(address(AddrClassicERC20.USDe), "USDE");
        vm.label(address(AddrClassicERC20.GHO), "GHO");
        vm.label(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, "ETH");

        // Volatiles
        vm.label(address(AddrClassicERC20.CRV), "CRV");
        vm.label(address(AddrClassicERC20.CVX), "CVX");
        vm.label(address(AddrClassicERC20.FXN), "FXN");
        vm.label(address(AddrClassicERC20.RLP), "RLP");

        // ETH
        vm.label(address(AddrClassicERC20.WETH), "WETH");
        vm.label(address(AddrClassicERC20.frxETH), "frxETH");
        vm.label(address(AddrClassicERC20.pxETH), "pxETH");

        // BTC
        vm.label(address(AddrClassicERC20.WBTC), "WBTC");
        vm.label(address(AddrClassicERC20.cbBTC), "cbBTC");
    }

    function labelizeERC4626() external {
        vm.label(address(AddrERC4626.sDAI), "sDAI");
        vm.label(address(AddrERC4626.scrvUSD), "scrvUSD");
        vm.label(address(AddrERC4626.REWARD_HANDLER_SCRVUSD), "scrvUSD Reward Handler");
        vm.label(address(AddrERC4626.sFRAX), "sFRAX");
        vm.label(address(AddrERC4626.sDOLA), "sDOLA");
        vm.label(address(AddrERC4626.sfrxUSD), "sfrxUSD");
        vm.label(address(AddrERC4626.sUSDe), "sUSDe");
        vm.label(address(AddrERC4626.wstUSR), "wstUSR");
    }

    function labeliseNewConvexCrvMarket(address collat, string calldata collatSymbol, address convexMarket, address cvxRewardToken) external {
        vm.label(collat, collatSymbol);
        if (address(cvxRewardToken) != address(0)) {
            vm.label(cvxRewardToken, string.concat("CvxRewardToken ", collatSymbol));
        }
        vm.label(convexMarket, string.concat("Market CvxCrv ", collatSymbol));
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
