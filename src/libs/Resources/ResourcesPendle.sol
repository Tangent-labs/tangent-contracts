// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPendleMarketV3} from "../../interfaces/externals/Pendle/IPendleMarketV3.sol";
import {IPendlePTToken} from "../../interfaces/externals/Pendle/IPendlePTToken.sol";
import {IPendleSYToken} from "../../interfaces/externals/Pendle/IPendleSYToken.sol";
import {IPendleYTToken} from "../../interfaces/externals/Pendle/IPendleYTToken.sol";

library AddrMarketPendle {
    IPendleMarketV3 constant eUSDe_29_05_25 = IPendleMarketV3(0x85667e484a32d884010Cf16427D90049CCf46e97);
    IPendleMarketV3 constant eBTC_26_06_25 = IPendleMarketV3(0x523f9441853467477b4dDE653c554942f8E17162);
    IPendleMarketV3 constant sUSDe_31_07_25 = IPendleMarketV3(0x4339Ffe2B7592Dc783ed13cCE310531aB366dEac);
    IPendleMarketV3 constant wstUSR_25_07_25 = IPendleMarketV3(0x09fA04Aac9c6d1c6131352EE950CD67ecC6d4fB9);
}

library AddrPTPendle {
    IPendlePTToken constant eUSDe_29_05_25 = IPendlePTToken(0x50D2C7992b802Eef16c04FeADAB310f31866a545);
    IPendlePTToken constant eBTC_26_06_25 = IPendlePTToken(0xc653F79de1274eE65674BeFda54986020d6f8FC1);
    IPendlePTToken constant sUSDe_31_07_25 = IPendlePTToken(0x3b3fB9C57858EF816833dC91565EFcd85D96f634);
    IPendlePTToken constant wstUSR_25_07_25 = IPendlePTToken(0x23E60d1488525bf4685f53b3aa8E676c30321066);
}

library AddrSYPendle {
    IPendleSYToken constant sUSDe_31_07_25 = IPendleSYToken(0xF541AA4d6f29ec2423A0D306dBc677021A02DBC0);
}
library AddrYTPendle {
    IPendleYTToken constant sUSDe_31_07_25 = IPendleYTToken(0xb7E51D15161C49C823f3951D579DEd61cD27272B);
}
