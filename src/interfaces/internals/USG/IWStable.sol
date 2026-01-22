// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IWStable is IERC20 {
    function stable() external view returns (address);
}
