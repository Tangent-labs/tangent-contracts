// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICollateral} from "../../../interfaces/internals/USG/ICollateral.sol";
import {IRewardAccumulator} from "../../../interfaces/internals/USG/IRewardAccumulator.sol";
import {IDebtIR} from "../../../interfaces/internals/USG/IDebtIR.sol";
import {IIRCalculator} from "../../../interfaces/internals/USG/IIRCalculator.sol";

import {IAggregatorStablePriceV3} from "../../../interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";
import {ERC20Infos, IERC20Metadata} from "../../ERC20Infos.sol";
import {GetMarketDetails} from "../GetMarketDetails.sol";
import {IYearnV3Vault} from "../../../interfaces/externals/YearnFi/IYearnV3Vault.sol";

contract MarketListUI is GetMarketDetails {
    struct MarketDetailsUIOut {
        uint256 USGPrice;
        uint256 USGSupply;
        uint256 sUSGPrice;
        uint256 sUSGSupply;
        uint256 USGPercentageInsUSG;
        MarketRow[] rowInfos;
    }

    error MarketDetailsUIOutError(MarketDetailsUIOut output);

    constructor(address account, IAggregatorStablePriceV3 USGOracle, IERC20Metadata USG, IYearnV3Vault sUSG, address[] memory markets, address[] memory pegKeepers) {
        MarketRow[] memory rows = new MarketRow[](markets.length);
        for (uint256 i; i < markets.length; i++) {
            rows[i] = getMarketDetails(account, markets[i]);
        }
        uint256 USGOnPegKeeper;

        for (uint256 i; i < pegKeepers.length; i++) {
            USGOnPegKeeper += USG.balanceOf(pegKeepers[i]);
        }

        uint256 USGTotalSupply = USG.totalSupply() - USGOnPegKeeper;
        uint256 USGPrice = USGOracle.price();
        revert MarketDetailsUIOutError(
            MarketDetailsUIOut({
                USGPrice: USGPrice,
                USGSupply: USGTotalSupply,
                sUSGPrice: (USGPrice * sUSG.pricePerShare()) / 1e18,
                sUSGSupply: sUSG.totalSupply(),
                USGPercentageInsUSG: USGTotalSupply == 0 ? 0 : (USG.balanceOf(address(sUSG)) * 1e18) / USGTotalSupply,
                rowInfos: rows
            })
        );
    }
}
