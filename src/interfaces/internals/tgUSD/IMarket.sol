// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "./IPriceOracle.sol";
import {ItgUSD} from "./ItgUSD.sol";
import {IMarket} from "./IMarket.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

interface IMarket {
    struct MarketInit {
        ItgUSD tgUSD;
        IPriceOracle tgUSDOracle;
        IERC20Metadata collatToken;
        IPriceOracle collatOracle;
        address irMinter;
        uint256 maxLTV;
        uint256 liquidationThreshold;
        uint256 maxMarketDebt;
        uint256 minimumLoan;
    }
}
