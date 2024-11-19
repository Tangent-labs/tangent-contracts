// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../../interfaces/internals/tgUSD/IPriceOracle.sol";
import "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";
import "forge-std/console.sol";

contract StableUSDOracle is IPriceOracle {
    ICurveStableSwapNG lp;

    IPriceOracle otherStableOracle;
    uint256 otherStableDecimals;

    constructor(ICurveStableSwapNG _lp, IPriceOracle _otherStableOracle) {
        lp = _lp;
        otherStableOracle = _otherStableOracle;
        otherStableDecimals = _otherStableOracle.decimals();
    }

    function latestAnswer() external view returns (uint256) {
        uint256 priceOtherStable = otherStableOracle.latestAnswer() * 10 ** (18 - otherStableDecimals);
        return (_priceOracle() * priceOtherStable) / 1 ether;
    }

    function decimals() external pure returns (uint256) {
        return 18;
    }

    function _priceOracle() internal view virtual returns (uint256) {}
}
