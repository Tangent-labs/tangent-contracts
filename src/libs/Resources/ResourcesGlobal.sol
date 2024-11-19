// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IAggregatorV3} from "../../interfaces/externals/Chainlink/IAggregatorV3.sol";
import {IPriceOracle} from "../../interfaces/internals/tgUSD/IPriceOracle.sol";

library AddrClassicERC20 {
    // Tokens
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
    IERC20Metadata constant TOKEN_SDAI = IERC20Metadata(0x83F20F44975D03b1b09e64809B757c47f942BEeA);
}

library AddrChainlinkOracle {
    // Tokens
    IAggregatorV3 constant CRVUSD = IAggregatorV3(0xEEf0C605546958c1f899b6fB336C20671f9cD49F);
    IAggregatorV3 constant USDC = IAggregatorV3(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
    IAggregatorV3 constant USDT = IAggregatorV3(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);
    IPriceOracle constant SDAI = IPriceOracle(0x29081f7aB5a644716EfcDC10D5c926c5fEe9F72B);
}
