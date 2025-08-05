// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IPendlePTToken is IERC20Metadata {
    function SY() external view returns (address);
    function YT() external view returns (address);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function burnByYT(address user, uint256 amount) external;
    function decimals() external view returns (uint8);
    function expiry() external view returns (uint256);
    function factory() external view returns (address);
    function initialize(address _YT) external;
    function isExpired() external view returns (bool);
    function mintByYT(address user, uint256 amount) external;
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
