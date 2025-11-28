// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {GlobalMarketInitParams, MarketInit} from "./IMarketCore.sol";
import {IStakeDaoVaultV2} from "../../externals/StakeDao/IStakeDaoVaultV2.sol";
interface IStakeDaoVaultV2Market {
    function initialize(GlobalMarketInitParams memory _marketConstants, MarketInit memory _marketInit, IStakeDaoVaultV2 _vault) external;
}
