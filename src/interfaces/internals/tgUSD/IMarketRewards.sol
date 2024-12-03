// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICommonStruct} from "../ICommonStruct.sol";
import {IMarketExternalActions} from "./IMarketExternalActions.sol";
interface IMarketRewards is IMarketExternalActions {
    function getAndUpdateRewards(address account) external returns (ICommonStruct.TokenAmount[] memory);
}
