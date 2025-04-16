// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IDebtIR} from "./IDebtIR.sol";

interface IControlTower {
    function isZapper(address zapper) external view returns (bool);

    function isMarket(address market) external view returns (bool);

    function isMarketCreator(address marketCreator) external view returns (bool);

    function isContractsMarkets(address[] calldata _markets) external view;

    function isIRCalculator(address irCalculator) external view returns (bool);

    function getFeeTreasuryAndVerifyContractsAreMarkets(address[] calldata _markets) external view returns (address);

    function feeTreasury() external view returns (address);

    function toggleMarket(address market) external;
}
