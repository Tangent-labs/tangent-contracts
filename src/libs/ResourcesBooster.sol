// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISdtStaking} from "../interfaces/internals/CVG/ISdtStaking.sol";
import {ICvxStaking} from "../interfaces/internals/CVG/ICvxStaking.sol";
import {ICvgCVX} from "../interfaces/internals/CVG/ICvgCVX.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library AddrBooster {
    ISdtStaking public constant SD_CRV_STAKING = ISdtStaking(0x2FF160bcADb485b5F048b9880e6f471Af632060c);
    ISdtStaking public constant SD_BAL_STAKING = ISdtStaking(0xAf5b3f4A0b4dc334dB7137E5584E0e971E5e4962);
    ISdtStaking public constant SD_PENDLE_STAKING = ISdtStaking(0x508f0E1b565b40AeB94671BeD228083203330882);
    ISdtStaking public constant SD_FXN_STAKING = ISdtStaking(0x35e30Bc815935Bb5EC1743f772331864D780cc26);

    ISdtStaking public constant CVG_SDT_STAKING = ISdtStaking(0xF941BC649Ef0B20ABd7f6dC78CA8f8E225337933);
    ICvxStaking public constant CVG_CVX_STAKING = ICvxStaking(0x2c1D293c50C6d1a4370ebb442A02c5956bbAb119);

    IERC20 public constant CVG_SDT = IERC20(0x830614aE209FF9d8706d386fcdBc7a55206fcffC);
    ICvgCVX public constant CVG_CVX = ICvgCVX(0x2191DF768ad71140F9F3E96c1e4407A4aA31d082);
    IERC20 public constant CVX1 = IERC20(0x6C9815826FdF8c7a45cCfEd2064dbaB33a078712);

    IERC20 public constant SD_CRV = IERC20(0xD1b5651E55D4CeeD36251c61c50C889B36F6abB5);
    IERC20 public constant SD_BAL = IERC20(0xF24d8651578a55b0C119B9910759a351A3458895);
    IERC20 public constant SD_PENDLE = IERC20(0x5Ea630e00D6eE438d3deA1556A110359ACdc10A9);
    IERC20 public constant SD_FXN = IERC20(0xe19d1c837B8A1C83A56cD9165b2c0256D39653aD);

    IERC20 public constant SD_CRV_GAUGE = IERC20(0x7f50786A0b15723D741727882ee99a0BF34e3466);
    IERC20 public constant SD_BAL_GAUGE = IERC20(0x3E8C72655e48591d93e6dfdA16823dB0fF23d859);
    IERC20 public constant SD_PENDLE_GAUGE = IERC20(0x50DC9aE51f78C593d4138263da7088A973b8184E);
    IERC20 public constant SD_FXN_GAUGE = IERC20(0xbcfE5c47129253C6B8a9A00565B3358b488D42E0);
}
