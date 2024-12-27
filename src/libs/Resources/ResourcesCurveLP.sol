// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import "../../interfaces/externals/Curve/ICurveStableSwapFactoryNG.sol";
library AddrCurveStableLP {
    ICurveStableSwapFactoryNG constant STABLE_SWAP_FACTORY = ICurveStableSwapFactoryNG(0x6A8cbed756804B16E05E741eDaBd5cB544AE21bf);

    ICurveStableSwapNG constant CRVUSD_USDC = ICurveStableSwapNG(0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E);
    ICurveStableSwapNG constant GHO_FXUSD = ICurveStableSwapNG(0x74345504Eaea3D9408fC69Ae7EB2d14095643c5b);
    ICurveStableSwapNG constant USDC_FXUSD = ICurveStableSwapNG(0x5018BE882DccE5E3F2f3B0913AE2096B9b3fB61f);
    ICurveStableSwapNG constant TRI_USD_LP = ICurveStableSwapNG(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    ICurveStableSwapNG constant FRXETH_WETH = ICurveStableSwapNG(0x9c3B46C0Ceb5B9e304FCd6D88Fc50f7DD24B31Bc);
    ICurveStableSwapNG constant PXETH_WETH = ICurveStableSwapNG(0xC8Eb2Cf2f792F77AF0Cd9e203305a585E588179D);

    IERC20Metadata constant TRI_USD_TOKEN = IERC20Metadata(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
}
