// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./StableUSDOracle.sol";
import "forge-std/console.sol";

contract StablePriceOracleNoParams is StableUSDOracle {
    constructor(ICurveStableSwapNG _lp, IPriceOracle _otherStableOracle) StableUSDOracle(_lp, _otherStableOracle) {}
    function _priceOracle() internal view override returns (uint256) {
        return lp.price_oracle();
    }
}
