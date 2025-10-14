// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICollateral} from "../../../interfaces/internals/USG/ICollateral.sol";
import {IDebtIR} from "../../../interfaces/internals/USG/IDebtIR.sol";
import {IIRCalculator} from "../../../interfaces/internals/USG/IIRCalculator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ERC20Infos, IERC20Metadata} from "../../ERC20Infos.sol";
import {GetMarketDetails} from "../GetMarketDetails.sol";
import {IYearnV3Vault} from "../../../interfaces/externals/YearnFi/IYearnV3Vault.sol";

import {ICurveCryptoSwap} from "../../../interfaces/externals/Curve/ICurveCryptoSwap.sol";
import {IAggregatorV3} from "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";
contract sTANUI is GetMarketDetails {
    struct sTANUIOut {
        uint256 tanPrice;
        uint256 sTanPrice;
        uint256 sTanSupply;
        uint256 tanPercentageInsTan;
        uint256 tanBalance;
        uint256 sTanBalance;
        uint256 tanAllowance;
    }

    error sTANUIOutError(sTANUIOut output);

    constructor(address account, ICurveCryptoSwap tanLP, IAggregatorV3 ethOracle, IERC20Metadata tan, IYearnV3Vault sTan, address dao) {
        uint256 ethPrice = ethOracle.latestAnswer() * 10 ** (ethOracle.decimals());

        // TAN price
        uint256 tanPriceInEth = 0;
        if (address(tanLP) != address(0)) {
            tanPriceInEth = tanLP.last_prices();
        }

        uint256 tanPrice = (tanPriceInEth * 1e18) / ethPrice;
        revert sTANUIOutError(
            sTANUIOut({
                tanPrice: tanPrice,
                sTanPrice: (tanPrice * sTan.pricePerShare()) / 1e18,
                sTanSupply: sTan.totalSupply(),
                tanPercentageInsTan: (tan.balanceOf(address(sTan)) * 1e18) / (tan.totalSupply() - tan.balanceOf(dao)),
                tanBalance: tan.balanceOf(account),
                sTanBalance: sTan.balanceOf(account),
                tanAllowance: tan.allowance(account, address(sTan))
            })
        );
    }
}
