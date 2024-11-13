// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICommonStruct, IERC20} from "../ICommonStruct.sol";

interface IRewardAccumulator {
    function incrementCutFees(ICommonStruct.TokenAmount[] memory cutFees) external;

    function cutFeeForToken(IERC20 token) external view returns (uint256);
}
