// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICollateral} from "../../../interfaces/internals/tgUSD/ICollateral.sol";
import {IRewards} from "../../../interfaces/internals/tgUSD/IRewards.sol";
import {IDebtIR} from "../../../interfaces/internals/tgUSD/IDebtIR.sol";
import {IIRCalculator} from "../../../interfaces/internals/tgUSD/IIRCalculator.sol";

import {IAggregatorStablePriceV3} from "../../../interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";
import {ERC20Infos, IERC20Metadata} from "../../ERC20Infos.sol";
import {GetMarketDetails} from "../GetMarketDetails.sol";
import {IYearnV3Vault} from "../../../interfaces/externals/YearnFi/IYearnV3Vault.sol";

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

    constructor(address account, IAggregatorStablePriceV3 tgUSDOracle, IERC20Metadata tgUSD, IYearnV3Vault sgUSD, address[] memory markets) {
        MarketRow[] memory rows = new MarketRow[](markets.length);
        for (uint256 i; i < markets.length; i++) {
            rows[i] = getMarketDetails(account, markets[i]);
        }
        uint256 tgUSDTotalSupply = tgUSD.totalSupply();
        uint256 tgUSDPrice = tgUSDOracle.price();
        revert MarketDetailsUIOutError(
            MarketDetailsUIOut({
                tgUSDPrice: tgUSDPrice,
                tgUSDSupply: tgUSDTotalSupply,
                sgUSDPrice: (tgUSDPrice * sgUSD.pricePerShare()) / 1e18,
                sgUSDSupply: sgUSD.totalSupply(),
                tgUSDPercentageInSgUSD: tgUSDTotalSupply == 0 ? 0 : (tgUSD.balanceOf(address(sgUSD)) * 1e18) / tgUSDTotalSupply,
                rowInfos: rows
            })
        );
    }
}
