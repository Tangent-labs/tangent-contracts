// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/console.sol";

import {ItgUSD} from "../../../src/interfaces/internals/tgUSD/ItgUSD.sol";

contract MockedOdosRouter {
    function swapCompact() external payable returns (uint256) {
        (ItgUSD tgUsd, address receiver, uint256 tgUsdMinted) = _decodeMockRouterOdosSwapCompact(msg.data);
        tgUsd.mint(receiver, tgUsdMinted);
        return tgUsdMinted;
    }

    function _decodeMockRouterOdosSwapCompact(bytes memory data) internal pure returns (ItgUSD, address, uint256) {
        address tgUsd;
        address receiver;
        uint256 tgUsdMinted;

        assembly {
            tgUsd := and(mload(add(data, 36)), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            receiver := and(mload(add(data, 68)), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            tgUsdMinted := calldataload(68)
        }

        return (ItgUSD(tgUsd), receiver, tgUsdMinted);
    }
}
