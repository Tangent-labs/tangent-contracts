// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IDebtIR} from "./IDebtIR.sol";

interface IControlTower {
    function isMarketCreator(address marketCreator) external view returns (bool);

    function isPositionMigrator(address migrator) external view returns (bool);

    function isPauser(address pauser) external view returns (bool);

    function feeTreasury() external view returns (address);
}
