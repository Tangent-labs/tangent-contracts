// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IYearnVaultFactory} from "../../interfaces/externals/YearnFi/IYearnVaultFactory.sol";

library AddrYearnFi {
    IYearnVaultFactory public constant VAULT_FACTORY = IYearnVaultFactory(0x770D0d1Fb036483Ed4AbB6d53c1C88fb277D812F);
}
