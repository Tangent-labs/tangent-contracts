// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IPriceOracle} from "../../../interfaces/internals/USG/IPriceOracle.sol";
import {ICurveStableSwapNG} from "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import {IAggregatorStablePriceV3} from "../../../interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

struct TokenOracle {
    IERC20Metadata token;
    address oracle;
}

contract LeverageMaxUI {
    mapping(IERC20Metadata => IPriceOracle) oracles;
    error LeverageMaxError(uint256);

    error NoOracleConfig(IERC20Metadata);

    constructor(ICurveStableSwapNG[] memory USGLPs, TokenOracle[] memory tokenOracles, IERC20Metadata USG, IAggregatorStablePriceV3 USGOracle, uint256 unbalanceMax) {
        for (uint256 i; i < tokenOracles.length; i++) {
            oracles[tokenOracles[i].token] = IPriceOracle(tokenOracles[i].oracle);
        }

        (ICurveStableSwapNG biggestLP, uint256 biggestTVL) = _findBiggestPool(USGLPs, USG, USGOracle.price());

        // Determine biggest LP for leverage

        uint256 USGIndex;
        uint256 otherStableIndex;
        IERC20Metadata coin0 = IERC20Metadata(biggestLP.coins(0));
        IERC20Metadata coin1 = IERC20Metadata(biggestLP.coins(1));
        uint256 otherStableDecimals;

        if (coin0 == USG) {
            USGIndex = 0;
            otherStableIndex = 1;
            otherStableDecimals = coin1.decimals();
        } else {
            USGIndex = 1;
            otherStableIndex = 0;
            otherStableDecimals = coin0.decimals();
        }

        uint256 balanceUSG = biggestLP.balances(USGIndex);
        uint256 balanceOtherStable = biggestLP.balances(otherStableIndex) * 10 ** (18 - otherStableDecimals);

        uint256 left = 0;
        uint256 right = biggestTVL;

        uint256 amountIn;

        uint256 _unbMax = unbalanceMax;
        for (uint256 i; i < 100; i++) {
            amountIn = left + (right - left) / 2;
            uint256 quote = biggestLP.get_dy(int128(uint128(USGIndex)), int128(uint128(otherStableIndex)), amountIn) * 10 ** (18 - otherStableDecimals);

            uint256 newUSGBalance = balanceUSG + amountIn;
            uint256 newOtherStableBalance = balanceOtherStable - quote;
            uint256 percentage = (newOtherStableBalance * 10 ** 18) / (newUSGBalance + newOtherStableBalance);

            if (percentage > _unbMax) {
                left = amountIn + 1;
            } else {
                right = amountIn;
            }
            if (percentage == _unbMax || left == right) {
                break;
            }
        }

        revert LeverageMaxError(amountIn);
    }

    function _findBiggestPool(ICurveStableSwapNG[] memory USGLPs, IERC20Metadata USG, uint256 USGPrice) internal view returns (ICurveStableSwapNG, uint256) {
        uint256 biggestTVL;
        ICurveStableSwapNG biggestLP;
        for (uint256 i; i < USGLPs.length; i++) {
            ICurveStableSwapNG lp = USGLPs[i];

            IERC20Metadata _coin0 = IERC20Metadata(lp.coins(0));
            IERC20Metadata _coin1 = IERC20Metadata(lp.coins(1));

            IERC20Metadata otherCoin;
            uint256 _USGIndex;
            uint256 _otherStableIndex;

            if (_coin0 == USG) {
                _USGIndex = 0;
                _otherStableIndex = 1;
                otherCoin = _coin1;
            } else {
                _USGIndex = 1;
                _otherStableIndex = 0;
                otherCoin = _coin0;
            }
            uint256 valueUSG = (lp.balances(_USGIndex) * USGPrice) / 1e18;
            uint256 valueOtherStable = (lp.balances(_otherStableIndex) *
                10 ** (18 - otherCoin.decimals()) *
                oracles[otherCoin].latestAnswer(true) *
                10 ** (18 - oracles[otherCoin].decimals())) / 1e18;

            uint256 totalStable = valueUSG + valueOtherStable;

            if (biggestTVL < totalStable) {
                biggestTVL = totalStable;
                biggestLP = lp;
            }
        }
        return (biggestLP, biggestTVL);
    }
}
