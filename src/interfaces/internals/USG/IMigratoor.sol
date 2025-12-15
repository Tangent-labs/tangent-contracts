// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IMarketExternalActions} from "./IMarketExternalActions.sol";

import {ZapStruct} from "../ICommonStruct.sol";
struct MigrateStruct {
    address marketFrom;
    address marketTo;
    uint256 collatToWithdraw;
    uint256 debtToRemove;
    uint256 debtToRepay;
}

struct ZapMigrateStruct {
    ZapStruct zap;
    uint256 minCollatToOut;
}

interface IMigratoor {}
