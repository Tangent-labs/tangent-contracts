// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/console.sol";

import {ITgUSD, IERC20} from "../../../src/interfaces/internals/tgUSD/ITgUSD.sol";
import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

contract MockEnsoRouterLeverage is StdCheats, StdUtils, Test {
    function swapCompact() external payable returns (uint256) {
        address tgUsd;
        address collatToken;
        address receiver;
        address mockedLp;
        uint256 tgUsdMinted;
        uint256 amountOutCollat;
        bytes memory data = msg.data;

        assembly {
            tgUsd := and(mload(add(data, 36)), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            collatToken := and(mload(add(data, 68)), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            receiver := and(mload(add(data, 100)), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            mockedLp := and(mload(add(data, 132)), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            tgUsdMinted := calldataload(132)
            amountOutCollat := calldataload(164)
        }
        IERC20(tgUsd).transfer(makeAddr("Mocked LP"), tgUsdMinted);
        deal(address(collatToken), receiver, amountOutCollat + IERC20(collatToken).balanceOf(receiver));

        return amountOutCollat;
    }
}
