// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import "../../interfaces/externals/Curve/ICurveStableSwapFactoryNG.sol";
library AddrCurveStableLP {
    ICurveStableSwapFactoryNG constant STABLE_SWAP_FACTORY = ICurveStableSwapFactoryNG(0x6A8cbed756804B16E05E741eDaBd5cB544AE21bf);
    
    ICurveStableSwapNG constant CRVUSD_USDC = ICurveStableSwapNG(0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E);
    ICurveStableSwapNG constant GHO_FXUSD = ICurveStableSwapNG(0x74345504Eaea3D9408fC69Ae7EB2d14095643c5b);
}
