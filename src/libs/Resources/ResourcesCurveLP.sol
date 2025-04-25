// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import "../../interfaces/externals/Curve/ICurveStableSwapFactoryNG.sol";

import "../../interfaces/externals/Curve/ICurveTriCryptoSwap.sol";
library AddrCurveStableLP {
    ICurveStableSwapFactoryNG constant STABLE_SWAP_FACTORY = ICurveStableSwapFactoryNG(0x6A8cbed756804B16E05E741eDaBd5cB544AE21bf);

    ICurveStableSwapNG constant USDC_crvUSD = ICurveStableSwapNG(0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E);
    ICurveStableSwapNG constant USDT_crvUSD = ICurveStableSwapNG(0x390f3595bCa2Df7d23783dFd126427CCeb997BF4);
    ICurveStableSwapNG constant DOLA_sUSDS = ICurveStableSwapNG(0x8b83c4aA949254895507D09365229BC3a8c7f710);
    ICurveStableSwapNG constant frxUSD_sUSDS = ICurveStableSwapNG(0x81A2612F6dEA269a6Dd1F6DeAb45C5424EE2c4b7);
    ICurveStableSwapNG constant GHO_fxUSD = ICurveStableSwapNG(0x74345504Eaea3D9408fC69Ae7EB2d14095643c5b);
    ICurveStableSwapNG constant USDC_fxUSD = ICurveStableSwapNG(0x5018BE882DccE5E3F2f3B0913AE2096B9b3fB61f);

    ICurveStableSwapNG constant TRI_USD_LP = ICurveStableSwapNG(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    ICurveStableSwapNG constant WETH_frxETH = ICurveStableSwapNG(0x9c3B46C0Ceb5B9e304FCd6D88Fc50f7DD24B31Bc);
    ICurveStableSwapNG constant WETH_pxETH = ICurveStableSwapNG(0xC8Eb2Cf2f792F77AF0Cd9e203305a585E588179D);

    ICurveStableSwapNG constant eBTC_WBTC = ICurveStableSwapNG(0x7704D01908afD31bf647d969c295BB45230cD2d6);

    IERC20Metadata constant TRI_USD_TOKEN = IERC20Metadata(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
}

library AddrCryptoSwapLP {
    // TRI
    ICurveTriCryptoSwap constant USDT_WBTC_ETH = ICurveTriCryptoSwap(0xf5f5B97624542D72A9E06f04804Bf81baA15e2B4);
    ICurveTriCryptoSwap constant USDC_WBTC_ETH = ICurveTriCryptoSwap(0x7F86Bf177Dd4F3494b841a37e810A34dD56c829B);
    ICurveTriCryptoSwap constant crvUSD_ETH_CRV = ICurveTriCryptoSwap(0x4eBdF703948ddCEA3B11f675B4D1Fba9d2414A14);
    ICurveTriCryptoSwap constant GHO_cbBTC_ETH = ICurveTriCryptoSwap(0x8a4f252812dFF2A8636E4F7EB249d8FC2E3bd77f);

    // DUO
    ICurveTriCryptoSwap constant USR_RLP = ICurveTriCryptoSwap(0xC907ba505C2E1cbc4658c395d4a2c7E6d2c32656);
    ICurveTriCryptoSwap constant CVX_ETH = ICurveTriCryptoSwap(0xB576491F1E6e5E62f1d8F26062Ee822B40B0E0d4);
}
