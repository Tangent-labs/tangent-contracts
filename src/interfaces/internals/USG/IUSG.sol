// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IUSG is IERC20 {
    function mintDebt(address to, uint256 amount) external;

    function burnDebt(address from, uint256 amount) external;

    function mintIR(uint256 amount) external;

    function initializeMarket(address market) external;
}
