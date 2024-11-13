// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICommonStruct} from "../ICommonStruct.sol";

interface IMarketRewards {
    function getAndUpdateRewards(address account) external returns (ICommonStruct.TokenAmount[] memory);
}
