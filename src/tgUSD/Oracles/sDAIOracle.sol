// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../interfaces/internals/tgUSD/IPriceOracle.sol";

import "forge-std/console.sol";

contract sDAIOracle is IPriceOracle {
    IPriceOracle public oracle;
    uint256 public oracleDecimals;

    constructor(IPriceOracle _oracle) {
        oracle = _oracle;
        oracleDecimals = oracle.decimals();
    }

    function latestAnswer() external view returns (uint256) {
        return oracle.latestAnswer() * 10 ** (18 - oracleDecimals);
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }
}
