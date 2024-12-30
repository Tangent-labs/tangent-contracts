// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../src/libs/Resources/ResourcesGlobal.sol";

import {Test} from "forge-std/Test.sol";

contract Labeliser is Test {
    function labelizeERC20() external {
        vm.label(address(AddrClassicERC20.TOKEN_DAI), "DAI");
        vm.label(address(AddrClassicERC20.TOKEN_FRAX), "FRAX");
        vm.label(address(AddrClassicERC20.TOKEN_USDT), "USDT");
        vm.label(address(AddrClassicERC20.TOKEN_CRVUSD), "CRVUSD");
        vm.label(address(AddrClassicERC20.TOKEN_CRV), "CRV");
        vm.label(address(AddrClassicERC20.TOKEN_CVX), "CVX");
        vm.label(address(AddrClassicERC20.TOKEN_USDC), "USDC");
        vm.label(address(AddrClassicERC20.TOKEN_FXN), "FXN");
        vm.label(address(AddrClassicERC20.TOKEN_DOLA), "DOLA");
        vm.label(address(AddrClassicERC20.TOKEN_FXUSD), "FXUSD");
    }

    function labelizeERC4626() external {
        vm.label(address(AddrERC4626.S_DAI), "sDAI");
        vm.label(address(AddrERC4626.S_CRVUSD), "sCRVUSD");
        vm.label(address(AddrERC4626.REWARD_HANDLER_SCRVUSD), "sCRVUSD Reward Handler");
        vm.label(address(AddrERC4626.S_FRAX), "sFRAX");
        vm.label(address(AddrERC4626.S_DOLA), "sDOLA");
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
