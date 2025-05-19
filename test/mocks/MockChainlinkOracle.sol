// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/console.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ITgUSD, IERC20} from "../../src/interfaces/internals/tgUSD/ITgUSD.sol";
import {IPriceOracle} from "../../src/interfaces/internals/tgUSD/IPriceOracle.sol";

import {Test} from "forge-std/Test.sol";

import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

contract MockChainlinkOracle is IPriceOracle {
    uint256 lastAns;
    uint8 dec;

    constructor(uint256 price, uint8 _decimals) {
        lastAns = price;
        dec = _decimals;
    }

    function latestAnswer() external view returns (uint256) {
        return lastAns;
    }

    function decimals() external view returns (uint8) {
        return dec;
    }

    function setLastAnswer(uint256 _newLastAnswer) external {
        lastAns = _newLastAnswer;
    }
}
