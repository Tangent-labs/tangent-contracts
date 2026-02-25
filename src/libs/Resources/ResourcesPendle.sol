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
    IPendleMarketV3 constant sUSDe_25_09_25 = IPendleMarketV3(0xA36b60A14A1A5247912584768C6e53E1a269a9F7);
    IPendleMarketV3 constant USDe_25_09_25 = IPendleMarketV3(0x6d98a2b6CDbF44939362a3E99793339Ba2016aF4);
    IPendleMarketV3 constant wstUSR_25_09_25 = IPendleMarketV3(0x09fA04Aac9c6d1c6131352EE950CD67ecC6d4fB9);
    IPendleMarketV3 constant USR_04_09_25 = IPendleMarketV3(0x33BdA865c6815c906e63878357335B28f063936c);
    IPendleMarketV3 constant USDe_27_11_25 = IPendleMarketV3(0x4eaA571EaFCD96f51728756BD7F396459BB9B869);
    IPendleMarketV3 constant sUSDe_27_11_25 = IPendleMarketV3(0xb6aC3d5da138918aC4E84441e924a20daA60dBdd);

    IPendleMarketV3 constant wstUSR_29_01_26 = IPendleMarketV3(0x39C3F8e0E7C6F44Dc8F0397FEb124517ba82e26E);
    IPendleMarketV3 constant sUSDe_05_02_26 = IPendleMarketV3(0xed81f8bA2941C3979de2265C295748a6b6956567);

    IPendleMarketV3 constant sUSDe_07_05_26 = IPendleMarketV3(0x8dAe8ECe668cf80d348873F23D456448E8694883);
    IPendleMarketV3 constant USDe_07_05_26 = IPendleMarketV3(0xA3336f04f7AfbF26714331e395054F33B77C9b8D);
}

library AddrPTPendle {
    IPendlePTToken constant eUSDe_29_05_25 = IPendlePTToken(0x50D2C7992b802Eef16c04FeADAB310f31866a545);
    IPendlePTToken constant eBTC_26_06_25 = IPendlePTToken(0xc653F79de1274eE65674BeFda54986020d6f8FC1);
    IPendlePTToken constant sUSDe_31_07_25 = IPendlePTToken(0x3b3fB9C57858EF816833dC91565EFcd85D96f634);
    IPendlePTToken constant sUSDe_25_09_25 = IPendlePTToken(0x9F56094C450763769BA0EA9Fe2876070c0fD5F77);
    IPendlePTToken constant USDe_25_09_25 = IPendlePTToken(0xBC6736d346a5eBC0dEbc997397912CD9b8FAe10a);
    IPendlePTToken constant wstUSR_25_09_25 = IPendlePTToken(0x23E60d1488525bf4685f53b3aa8E676c30321066);
    IPendlePTToken constant USR_04_09_25 = IPendlePTToken(0x5a5b93F762739fa94F3EcC0b34Af2e56702E7f70);
    IPendlePTToken constant sUSDe_27_11_25 = IPendlePTToken(0xe6A934089BBEe34F832060CE98848359883749B3);
    IPendlePTToken constant USDe_27_11_25 = IPendlePTToken(0x62C6E813b9589C3631Ba0Cdb013acdB8544038B7);
    IPendlePTToken constant wstUSR_29_01_26 = IPendlePTToken(0xfCeEB7586bab730fA400A5BF3FcF298d0DB4c7e7);
    IPendlePTToken constant sUSDe_05_02_26 = IPendlePTToken(0xE8483517077afa11A9B07f849cee2552f040d7b2);

    IPendlePTToken constant sUSDe_07_05_26 = IPendlePTToken(0x3de0ff76E8b528C092d47b9DaC775931cef80F49);
    IPendlePTToken constant USDe_07_05_26 = IPendlePTToken(0xAeBf0Bb9f57E89260d57f31AF34eB58657d96Ce0);
}

library AddrSYPendle {
    IPendleSYToken constant sUSDe_31_07_25 = IPendleSYToken(0xF541AA4d6f29ec2423A0D306dBc677021A02DBC0);
    IPendleSYToken constant sUSDe_25_09_25 = IPendleSYToken(0xC01cde799245a25e6EabC550b36A47F6F83cc0f1);
    IPendleSYToken constant USDe_25_09_25 = IPendleSYToken(0xf3DbdE762E5B67FaD09d88da3dfD38A83f753FFe);
    IPendleSYToken constant wstUSR_25_09_25 = IPendleSYToken(0x6c78661c00D797C9c7fCBE4BCacbD9612A61C07f);
    IPendleSYToken constant USR_04_09_25 = IPendleSYToken(0x6AFde97a0c27e57cf0582373F9D7dc2b9f1CC3A3);
    IPendleSYToken constant sUSDe_27_11_25 = IPendleSYToken(0xAbf8165dD7a90ab75878161db15Bf85F6F781d9b);
    IPendleSYToken constant USDe_27_11_25 = IPendleSYToken(0x925a15bD6A1582fa7c0EbbFc3Dbd29c34f58340e);
    IPendleSYToken constant wstUSR_29_01_26 = IPendleSYToken(0x6c78661c00D797C9c7fCBE4BCacbD9612A61C07f);
    IPendleSYToken constant sUSDe_05_02_26 = IPendleSYToken(0x50CBf8837791aB3D8dcfB3cE3d1B0d128e1105d4);

    IPendleSYToken constant sUSDe_07_05_26 = IPendleSYToken(0xBF98480425A29197e5d99D003017f63a1e595D02);
    IPendleSYToken constant USDe_07_05_26 = IPendleSYToken(0xf0bAcD9C3D94fC924DBcaaF644208C4E3f4d3bB4);
}
library AddrYTPendle {
    IPendleYTToken constant sUSDe_31_07_25 = IPendleYTToken(0xb7E51D15161C49C823f3951D579DEd61cD27272B);
    IPendleYTToken constant sUSDe_25_09_25 = IPendleYTToken(0x029d6247ADb0A57138c62E3019C92d3dfC9c1840);
    IPendleYTToken constant USDe_25_09_25 = IPendleYTToken(0x48bbbEdc4d2491cc08915D7a5c7cc8A8EdF165da);
    IPendleYTToken constant wstUSR_25_09_25 = IPendleYTToken(0x1E24B022329f3CA0083b12FAF75d19639FAebF6f);
    IPendleYTToken constant USR_04_09_25 = IPendleYTToken(0x9ebd88a0368D53fdCAd9c72C47280fECBcCDCAA9);
    IPendleYTToken constant sUSDe_27_11_25 = IPendleYTToken(0x28E626b560F1FaaC01544770425e2De8FD179c79);
    IPendleYTToken constant USDe_27_11_25 = IPendleYTToken(0x99C92D4Da7a81c7698EF33a39D7538d0f92623f7);
    IPendleYTToken constant wstUSR_29_01_26 = IPendleYTToken(0x112B56037552d9A5142493F44480BA98C2586805);
    IPendleYTToken constant sUSDe_05_02_26 = IPendleYTToken(0xe36c6c271779C080Ba2e68E1E68410291a1b3F7A);

    IPendleYTToken constant sUSDe_07_05_26 = IPendleYTToken(0x30775B422b9c7415349855346352FAA61fD97E41);
    IPendleYTToken constant USDe_07_05_26 = IPendleYTToken(0x4265ebF36F738D4D623C201BecBbc0f92bE57198);
}
