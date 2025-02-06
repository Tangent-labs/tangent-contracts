// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICollateral} from "../../../interfaces/internals/tgUSD/ICollateral.sol";
import {IRewards} from "../../../interfaces/internals/tgUSD/IRewards.sol";
import {IDebtIR} from "../../../interfaces/internals/tgUSD/IDebtIR.sol";
import {IIRCalculator} from "../../../interfaces/internals/tgUSD/IIRCalculator.sol";

import {IPriceAggregatorV2} from "../../../interfaces/externals/LlamaLend/IPriceAggregatorV2.sol";
import {ERC20Infos, IERC20Metadata} from "../../ERC20Infos.sol";
import {GetMarketDetails} from "../GetMarketDetails.sol";
import {IYearnV3Vault} from "../../../interfaces/externals/YearnFi/IYearnV3Vault.sol";

contract SgUSDUI is GetMarketDetails {
    struct SgUSDUIOut {
        uint256 tgUSDPrice;
        uint256 tgUSDSupply;
        uint256 sgUSDPrice;
        uint256 sgUSDSupply;
        uint256 tgUSDPercentageInSgUSD;
        uint256 tgUSDBalance;
        uint256 sgUSDBalance;
        uint256 tgUSDAllowance;
    }

    error SgUSDUIOutError(SgUSDUIOut output);

    constructor(address account, IPriceAggregatorV2 tgUSDOracle, IERC20Metadata tgUSD, IYearnV3Vault sgUSD) {
        uint256 tgUSDTotalSupply = tgUSD.totalSupply();
        uint256 tgUSDPrice = tgUSDOracle.price();
        revert SgUSDUIOutError(
            SgUSDUIOut({
                tgUSDPrice: tgUSDPrice,
                tgUSDSupply: tgUSDTotalSupply,
                sgUSDPrice: (tgUSDPrice * sgUSD.pricePerShare()) / 1e18,
                sgUSDSupply: sgUSD.totalSupply(),
                tgUSDPercentageInSgUSD: tgUSDTotalSupply == 0 ? 0 : (tgUSD.balanceOf(address(sgUSD)) * 1e18) / tgUSDTotalSupply,
                tgUSDBalance: tgUSD.balanceOf(account),
                sgUSDBalance: sgUSD.balanceOf(account),
                tgUSDAllowance: tgUSD.allowance(account, address(sgUSD))
            })
        );
    }
}
