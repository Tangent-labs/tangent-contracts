// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICvxBooster} from "../../interfaces/externals/Convex/ICvxBooster.sol";
import {ICvxFxnBooster} from "../../interfaces/externals/Convex/ICvxFxnBooster.sol";
import {ICvxRewardToken} from "../../interfaces/externals/Convex/ICvxRewardToken.sol";

library AddrCvxGlobal {
    ICvxBooster constant CVX_BOOSTER = ICvxBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    ICvxFxnBooster constant CVX_FXN_BOOSTER = ICvxFxnBooster(0xAffe966B27ba3E4Ebb8A0eC124C7b7019CC762f8);
    address constant CVX_VOTER_PROXY = 0x989AEb4d175e16225E39E87d0D97A3360524AD80;
}
library AddrCvxRewardTokens {
    ICvxRewardToken constant CRVUSD_CRV = ICvxRewardToken(0x4bf2d8484474170bff8a8c34475be3d87dFF28cA);
    ICvxRewardToken constant CRVUSD_LEVERAGE_WETH = ICvxRewardToken(0xcE2E915Dd0530E66Cfc34b7421E9A93F09A9A6b5);
    ICvxRewardToken constant CRVUSD_TBTC = ICvxRewardToken(0x57e94F41E596FC8315B20321156421c20CdC93f9);
    ICvxRewardToken constant CRVUSD_SUSDE = ICvxRewardToken(0xED2a17704bC5D5a7c5d256228333026B76A1732e);
    ICvxRewardToken constant CRVUSD_WETH = ICvxRewardToken(0xADde9073d897743E7004115Fa2452cC959FBF28a);
    ICvxRewardToken constant CRVUSD_WSTETH = ICvxRewardToken(0xbe3C3Fd181af6B99CC1bb9b0Ee065318aDFc4c96);
    ICvxRewardToken constant CRVUSD_LEVERAGE_WBTC = ICvxRewardToken(0xfe382f1Bf78e6D6012cB38C284Fe123ec9821966);

    ICvxRewardToken constant USDC_crvUSD_LP = ICvxRewardToken(0x44D8FaB7CD8b7877D5F79974c2F501aF6E65AbBA);
    ICvxRewardToken constant USDT_crvUSD_LP = ICvxRewardToken(0xD1DdB0a0815fD28932fBb194C84003683AF8a824);
    ICvxRewardToken constant WETH_frxETH_LP = ICvxRewardToken(0xFafDE12dC476C4913e29F47B4747860C148c5E4f);
    ICvxRewardToken constant WETH_pxETH_LP = ICvxRewardToken(0x3B793E505A3C7dbCb718Fe871De8eBEf7854e74b);
    ICvxRewardToken constant ETH_stETH_LP = ICvxRewardToken(0x0A760466E1B4621579a82a39CB56Dda2F4E70f03);
    ICvxRewardToken constant CVX_ETH_LP = ICvxRewardToken(0xb1Fb0BA0676A1fFA83882c7F4805408bA232C1fA);
    ICvxRewardToken constant scrvUSD_sDOLA_LP = ICvxRewardToken(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
}

library AddrCvxVaultTokens {
    IERC20 constant CRVUSD_CRV = ICvxRewardToken(0xf0ac58AF1ca98aFce29fAe456E853688ab9d41E2);
    IERC20 constant CRVUSD_LEVERAGE_WETH = ICvxRewardToken(0xd6Ab4Ca1fb1D3993db4d37b04621D28B669b671E);
    IERC20 constant CRVUSD_LEVERAGE_WBTC = ICvxRewardToken(0xDF2Cf819DBC1E5a5774eE760D2678330cf4665e2);
}

library PidCvxCrvBooster {
    uint256 constant CRVUSD_CRV = 325;
    uint256 constant CRVUSD_LEVERAGE_WETH = 365;
    uint256 constant CRVUSD_TBTC = 328;
    uint256 constant CRVUSD_SUSDE = 361;
    uint256 constant CRVUSD_WSTETH = 364;
    uint256 constant CRVUSD_LEVERAGE_WBTC = 344;

    uint256 constant USDT_crvUSD_LP = 179;
    uint256 constant USDC_crvUSD_LP = 182;
    uint256 constant WETH_frxETH_LP = 219;
    uint256 constant WETH_pxETH_LP = 271;
    uint256 constant ETH_stETH_LP = 25;
    uint256 constant CVX_ETH_LP = 64;
    uint256 constant scrvUSD_sDOLA_LP = 400;
    uint256 constant sUSDS_USDT_LP = 400;
}

library PidCvxFxnBooster {
    uint256 constant USDC_fxUSD_LP = 32;
    uint256 constant FX_V2_STABILITY_POOL = 36;
}
