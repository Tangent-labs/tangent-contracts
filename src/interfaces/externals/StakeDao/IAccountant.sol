// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IAccountant {
    function claim(address[] calldata _gauges, bytes[] calldata harvestData) external;
    function accounts(address vault, address account) external view returns (uint128, uint256, uint256);

    function vaults(address vault) external view returns (uint256, uint128, uint128, uint128, uint128, uint128, uint128);
}
