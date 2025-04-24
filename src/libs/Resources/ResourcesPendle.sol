// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library AddrPTPendle {
    IERC20Metadata constant SUSDE_31_07_2025 = IERC20Metadata(0x3b3fB9C57858EF816833dC91565EFcd85D96f634);
}

library AddrMarketPendle {
    address constant SUSDE_31_07_2025 = 0x4339Ffe2B7592Dc783ed13cCE310531aB366dEac;
}
