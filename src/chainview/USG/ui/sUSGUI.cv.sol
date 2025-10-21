// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICollateral} from "../../../interfaces/internals/USG/ICollateral.sol";
import {IDebtIR} from "../../../interfaces/internals/USG/IDebtIR.sol";
import {IIRCalculator} from "../../../interfaces/internals/USG/IIRCalculator.sol";

import {IAggregatorStablePriceV3} from "../../../interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";
import {ERC20Infos, IERC20Metadata} from "../../ERC20Infos.sol";
import {GetMarketDetails} from "../GetMarketDetails.sol";
import {IYearnV3Vault} from "../../../interfaces/externals/YearnFi/IYearnV3Vault.sol";

contract sUSGUI is GetMarketDetails {
    struct sUSGUIOut {
        uint256 USGPrice;
        uint256 USGSupply;
        uint256 sUSGPrice;
        uint256 sUSGSupply;
        uint256 USGPercentageInsUSG;
        uint256 USGBalance;
        uint256 sUSGBalance;
        uint256 USGAllowance;
    }

    error sUSGUIOutError(sUSGUIOut output);

    constructor(address account, IAggregatorStablePriceV3 USGOracle, IERC20Metadata USG, IYearnV3Vault sUSG) {
        uint256 USGTotalSupply = USG.totalSupply();
        uint256 USGPrice = USGOracle.price();
        revert sUSGUIOutError(
            sUSGUIOut({
                USGPrice: USGPrice,
                USGSupply: USGTotalSupply,
                sUSGPrice: (USGPrice * sUSG.pricePerShare()) / 1e18,
                sUSGSupply: sUSG.totalSupply(),
                USGPercentageInsUSG: USGTotalSupply == 0 ? 0 : (USG.balanceOf(address(sUSG)) * 1e18) / USGTotalSupply,
                USGBalance: account == address(0) ? 0 : USG.balanceOf(account),
                sUSGBalance: account == address(0) ? 0 : sUSG.balanceOf(account),
                USGAllowance: USG.allowance(account, address(sUSG))
            })
        );
    }
}
