// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IscvUSD} from "./IscvUSD.sol";

interface ISplitterTokenComp is IERC20 {
    function convertToAssets(uint256 shares) external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);

    function mintSplitter(address receiver, uint256 assets, IscvUSD scvUSD) external returns (uint256);
    function burnSplitter(address from, uint256 shares) external returns (uint256);
}
