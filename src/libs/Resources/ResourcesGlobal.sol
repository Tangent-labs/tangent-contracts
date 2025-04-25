// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAggregatorV3} from "../../interfaces/externals/Chainlink/IAggregatorV3.sol";
import {IOdosRouter} from "../../interfaces/externals/Aggregators/IOdosRouter.sol";
import {IEnsoRouterV2} from "../../interfaces/externals/Aggregators/IEnsoRouterV2.sol";

import {ISFRAX} from "../../interfaces/externals/Frax/ISFRAX.sol";
import {ICurveRouter} from "../../interfaces/externals/Curve/ICurveRouter.sol";
import {IPriceOracle} from "../../interfaces/internals/tgUSD/IPriceOracle.sol";
import {IRewardsHandler} from "../../interfaces/internals/tgUSD/IRewardsHandler.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

library AddrClassicERC20 {
    // Stablecoins
    IERC20Metadata constant DAI = IERC20Metadata(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20Metadata constant FRAX = IERC20Metadata(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    IERC20Metadata constant USDT = IERC20Metadata(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20Metadata constant crvUSD = IERC20Metadata(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);
    IERC20Metadata constant USDC = IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Metadata constant DOLA = IERC20Metadata(0x865377367054516e17014CcdED1e7d814EDC9ce4);
    IERC20Metadata constant fxUSD = IERC20Metadata(0x085780639CC2cACd35E474e71f4d000e2405d8f6);
    IERC20Metadata constant GHO = IERC20Metadata(0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f);
    IERC20Metadata constant frxUSD = IERC20Metadata(0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29);
    IERC20Metadata constant USR = IERC20Metadata(0x66a1E37c9b0eAddca17d3662D6c05F4DECf3e110);
    IERC20Metadata constant stUSR = IERC20Metadata(0x6c8984bc7DBBeDAf4F6b2FD766f16eBB7d10AAb4);
    IERC20Metadata constant USDe = IERC20Metadata(0x4c9EDD5852cd905f086C759E8383e09bff1E68B3);
    IERC20Metadata constant USDS = IERC20Metadata(0xdC035D45d973E3EC169d2276DDab16f1e407384F);

    // Volatiles
    IERC20Metadata constant AAVE = IERC20Metadata(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);
    IERC20Metadata constant BAL = IERC20Metadata(0xba100000625a3754423978a60c9317c58a424e3D);
    IERC20Metadata constant _80_BAL_20_ETH = IERC20Metadata(0x5c6Ee304399DBdB9C8Ef030aB642B10820DB8F56);
    IERC20Metadata constant CRV = IERC20Metadata(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IERC20Metadata constant PENDLE = IERC20Metadata(0x808507121B80c02388fAd14726482e061B8da827);
    IERC20Metadata constant FXN = IERC20Metadata(0x365AccFCa291e7D3914637ABf1F7635dB165Bb09);
    IERC20Metadata constant SDT = IERC20Metadata(0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F);
    IERC20Metadata constant CVX = IERC20Metadata(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    IERC20Metadata constant RLP = IERC20Metadata(0x4956b52aE2fF65D74CA2d61207523288e4528f96);

    // ETH
    IERC20Metadata constant WETH = IERC20Metadata(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Metadata constant frxETH = IERC20Metadata(0x5E8422345238F34275888049021821E8E08CAa1f);
    IERC20Metadata constant pxETH = IERC20Metadata(0x04C154b66CB340F3Ae24111CC767e0184Ed00Cc6);

    // BTC
    IERC20Metadata constant WBTC = IERC20Metadata(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20Metadata constant cbBTC = IERC20Metadata(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);
    IERC20Metadata constant eBTC = IERC20Metadata(0x657e8C867D8B37dCC18fA4Caead9C45EB088C642);
}

library AddrERC4626 {
    IERC4626 constant scrvUSD = IERC4626(0x0655977FEb2f289A4aB78af67BAB0d17aAb84367);
    IRewardsHandler constant REWARD_HANDLER_SCRVUSD = IRewardsHandler(0xE8d1E2531761406Af1615A6764B0d5fF52736F56);
    IERC4626 constant sDAI = IERC4626(0x83F20F44975D03b1b09e64809B757c47f942BEeA);
    ISFRAX constant sFRAX = ISFRAX(0xA663B02CF0a4b149d2aD41910CB81e23e1c41c32);
    IERC4626 constant sDOLA = IERC4626(0xb45ad160634c528Cc3D2926d9807104FA3157305);
    IERC4626 constant sfrxUSD = IERC4626(0xcf62F905562626CfcDD2261162a51fd02Fc9c5b6);
    IERC4626 constant sUSDe = IERC4626(0x9D39A5DE30e57443BfF2A8307A4256c8797A3497);
    IERC4626 constant wstUSR = IERC4626(0x1202F5C7b4B9E47a1A484E8B270be34dbbC75055);
    IERC4626 constant sUSDS = IERC4626(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD);
}

library AddrChainlinkOracle {
    // Stablecoins
    IAggregatorV3 constant DAI = IAggregatorV3(0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9);
    IAggregatorV3 constant crvUSD = IAggregatorV3(0xEEf0C605546958c1f899b6fB336C20671f9cD49F);
    IAggregatorV3 constant USDC = IAggregatorV3(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
    IAggregatorV3 constant USDT = IAggregatorV3(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);
    IPriceOracle constant sDAI = IPriceOracle(0x29081f7aB5a644716EfcDC10D5c926c5fEe9F72B);
    IAggregatorV3 constant GHO = IAggregatorV3(0x3f12643D3f6f874d39C2a4c9f2Cd6f2DbAC877FC);
    IAggregatorV3 constant USD0 = IAggregatorV3(0x7e891DEbD8FA0A4Cf6BE58Ddff5a8ca174FebDCB);
    IAggregatorV3 constant TUSD = IAggregatorV3(0xec746eCF986E2927Abd291a2A1716c940100f8Ba);
    IAggregatorV3 constant USDS = IAggregatorV3(0xfF30586cD0F29eD462364C7e81375FC0C71219b1);
    IAggregatorV3 constant USDP = IAggregatorV3(0x09023c0DA49Aaf8fc3fA3ADF34C6A7016D38D5e3);
    IAggregatorV3 constant USDe = IAggregatorV3(0xa569d910839Ae8865Da8F8e70FfFb0cBA869F961);
    IAggregatorV3 constant USR = IAggregatorV3(0x34ad75691e25A8E9b681AAA85dbeB7ef6561B42c); //TODO High Market risk

    // ETH
    IAggregatorV3 constant ETH = IAggregatorV3(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    IAggregatorV3 constant ezETH = IAggregatorV3(0x636A000262F6aA9e1F094ABF0aD8f645C44f641C);
    IAggregatorV3 constant CRV = IAggregatorV3(0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f);

    // BTC
    IAggregatorV3 constant BTC = IAggregatorV3(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);
    IAggregatorV3 constant cbBTC = IAggregatorV3(0x2665701293fCbEB223D11A08D826563EDcCE423A);
}

library AddrRouter {
    IOdosRouter constant ODOS_ROUTER = IOdosRouter(0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559);
    IEnsoRouterV2 constant ENSO_ROUTER_V1 = IEnsoRouterV2(0x80EbA3855878739F4710233A8a19d89Bdd2ffB8E);
    IEnsoRouterV2 constant ENSO_ROUTER_V2 = IEnsoRouterV2(0xF75584eF6673aD213a685a1B58Cc0330B8eA22Cf);

    ICurveRouter constant ROUTER_CURVE = ICurveRouter(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);
}
