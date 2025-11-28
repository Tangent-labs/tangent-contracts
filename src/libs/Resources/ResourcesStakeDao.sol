// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStakeDaoVaultV2} from "../../interfaces/externals/StakeDao/IStakeDaoVaultV2.sol";

library AddrStakeDaoVaultV2 {
    IStakeDaoVaultV2 constant USDC_crvUSD_LP = IStakeDaoVaultV2(0xD4467fBCBd3511112D2FD1af667E745D4987C8eb);
    IStakeDaoVaultV2 constant USDT_crvUSD_LP = IStakeDaoVaultV2(0xF980f195A93577DcCe48e91e98124D3B71C4a066);
}
