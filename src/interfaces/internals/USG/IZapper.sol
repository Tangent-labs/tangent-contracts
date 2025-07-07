// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IZapper {
    function zapLeverage(IERC20 collatToken, uint256 minCollatReceived, bytes calldata routerCall) external returns (uint256);
}
