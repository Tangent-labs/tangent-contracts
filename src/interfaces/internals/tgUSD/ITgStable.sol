// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface ITgStable is IERC20 {
    function mint(address to, uint256 amount, bool isStaked) external;
}
