// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAggregatorV3} from "../../interfaces/externals/Chainlink/IAggregatorV3.sol";
import {IOdosRouter} from "../../interfaces/externals/Aggregators/IOdosRouter.sol";
import {IEnsoRouter} from "../../interfaces/externals/Aggregators/IEnsoRouter.sol";

import {ISFRAX} from "../../interfaces/externals/Frax/ISFRAX.sol";

import {IPriceOracle} from "../../interfaces/internals/tgUSD/IPriceOracle.sol";
import {IRewardsHandler} from "../../interfaces/internals/tgUSD/IRewardsHandler.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

library AddrClassicERC20 {
    // Tokens
    IERC20Metadata constant TOKEN_DAI = IERC20Metadata(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20Metadata constant TOKEN_FRAX = IERC20Metadata(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    IERC20Metadata constant TOKEN_USDT = IERC20Metadata(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20Metadata constant TOKEN_CRVUSD = IERC20Metadata(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);
    IERC20Metadata constant TOKEN_SDT = IERC20Metadata(0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F);
    IERC20Metadata constant TOKEN_CRV = IERC20Metadata(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IERC20Metadata constant TOKEN_CVX = IERC20Metadata(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    IERC20Metadata constant TOKEN_USDC = IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Metadata constant TOKEN_AAVE = IERC20Metadata(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);
    IERC20Metadata constant TOKEN_BAL = IERC20Metadata(0xba100000625a3754423978a60c9317c58a424e3D);
    IERC20Metadata constant TOKEN_80_BAL_20_ETH = IERC20Metadata(0x5c6Ee304399DBdB9C8Ef030aB642B10820DB8F56);
    IERC20Metadata constant TOKEN_PENDLE = IERC20Metadata(0x808507121B80c02388fAd14726482e061B8da827);
    IERC20Metadata constant TOKEN_FXN = IERC20Metadata(0x365AccFCa291e7D3914637ABf1F7635dB165Bb09);
    IERC20Metadata constant TOKEN_DOLA = IERC20Metadata(0x865377367054516e17014CcdED1e7d814EDC9ce4);
    IERC20Metadata constant TOKEN_FXUSD = IERC20Metadata(0x085780639CC2cACd35E474e71f4d000e2405d8f6);
    IERC20Metadata constant TOKEN_FRXETH = IERC20Metadata(0x5E8422345238F34275888049021821E8E08CAa1f);
    IERC20Metadata constant TOKEN_PXETH = IERC20Metadata(0x04C154b66CB340F3Ae24111CC767e0184Ed00Cc6);
}

library AddrERC4626 {
    IERC4626 constant S_CRVUSD = IERC4626(0x0655977FEb2f289A4aB78af67BAB0d17aAb84367);
    IRewardsHandler constant REWARD_HANDLER_SCRVUSD = IRewardsHandler(0xE8d1E2531761406Af1615A6764B0d5fF52736F56);
    IERC4626 constant S_DAI = IERC4626(0x83F20F44975D03b1b09e64809B757c47f942BEeA);
    ISFRAX constant S_FRAX = ISFRAX(0xA663B02CF0a4b149d2aD41910CB81e23e1c41c32);
    IERC4626 constant S_DOLA = IERC4626(0xb45ad160634c528Cc3D2926d9807104FA3157305);
}

library AddrChainlinkOracle {
    // Tokens
    IAggregatorV3 constant DAI = IAggregatorV3(0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9);
    IAggregatorV3 constant CRVUSD = IAggregatorV3(0xEEf0C605546958c1f899b6fB336C20671f9cD49F);
    IAggregatorV3 constant ETH = IAggregatorV3(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    IAggregatorV3 constant USDC = IAggregatorV3(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
    IAggregatorV3 constant USDT = IAggregatorV3(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);
    IPriceOracle constant SDAI = IPriceOracle(0x29081f7aB5a644716EfcDC10D5c926c5fEe9F72B);
    IAggregatorV3 constant GHO = IAggregatorV3(0x3f12643D3f6f874d39C2a4c9f2Cd6f2DbAC877FC);
    IAggregatorV3 constant USD0 = IAggregatorV3(0x7e891DEbD8FA0A4Cf6BE58Ddff5a8ca174FebDCB);
    IAggregatorV3 constant TUSD = IAggregatorV3(0xec746eCF986E2927Abd291a2A1716c940100f8Ba);
    IAggregatorV3 constant USDS = IAggregatorV3(0xfF30586cD0F29eD462364C7e81375FC0C71219b1);
    IAggregatorV3 constant USDP = IAggregatorV3(0x09023c0DA49Aaf8fc3fA3ADF34C6A7016D38D5e3);
    IAggregatorV3 constant USDE = IAggregatorV3(0xa569d910839Ae8865Da8F8e70FfFb0cBA869F961);
    IAggregatorV3 constant EZ_ETH = IAggregatorV3(0x636A000262F6aA9e1F094ABF0aD8f645C44f641C);
    IAggregatorV3 constant CB_BTC = IAggregatorV3(0x2665701293fCbEB223D11A08D826563EDcCE423A);
}

library AddrAggregator {
    IOdosRouter constant ODOS_ROUTER = IOdosRouter(0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559);
    IEnsoRouter constant ENSO_ROUTER = IEnsoRouter(0x80EbA3855878739F4710233A8a19d89Bdd2ffB8E);
}
