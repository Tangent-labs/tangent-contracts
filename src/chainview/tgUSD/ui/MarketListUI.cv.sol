// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICollateral} from "../../../interfaces/internals/tgUSD/ICollateral.sol";
import {IRewards} from "../../../interfaces/internals/tgUSD/IRewards.sol";
import {IDebtIR} from "../../../interfaces/internals/tgUSD/IDebtIR.sol";
import {IIRCalculator} from "../../../interfaces/internals/tgUSD/IIRCalculator.sol";

import {IPriceOracle} from "../../../interfaces/internals/tgUSD/IPriceOracle.sol";
import {ERC20Infos, IERC20Metadata} from "../../ERC20Infos.sol";
import {GetMarketDetails} from "../GetMarketDetails.sol";

contract MarketListUI is GetMarketDetails {
    struct MarketDetailsUIOut {
        uint256 tgUSDPrice;
        uint256 tgUSDSupply;
        uint256 sgUSDPrice;
        uint256 sgUSDSupply;
        uint256 tgUSDPercentageInSgUSD;
        MarketRow[] rowInfos;
    }

    error MarketDetailsUIOutError(MarketDetailsUIOut output);

    constructor(address account, IPriceOracle tgUSDOracle, IERC20Metadata tgUSD, address[] memory markets) {
        MarketRow[] memory rows = new MarketRow[](markets.length);
        for (uint256 i; i < markets.length; i++) {
            rows[i] = getMarketDetails(account, markets[i]);
        }
        revert MarketDetailsUIOutError(
            MarketDetailsUIOut({tgUSDPrice: tgUSDOracle.latestAnswer(), tgUSDSupply: tgUSD.totalSupply(), sgUSDPrice: 0, sgUSDSupply: 0, tgUSDPercentageInSgUSD: 0, rowInfos: rows})
        );
    }
}
