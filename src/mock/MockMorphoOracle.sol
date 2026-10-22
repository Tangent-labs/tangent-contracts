// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Morpho Blue IOracle: price of 1 collateral token quoted in loan token,
/// scaled by 1e36 (both sUSG and frxUSD have 18 decimals).
contract MockMorphoOracle {
    uint256 public price;

    constructor(uint256 _price) {
        price = _price;
    }

    function setPrice(uint256 _price) external {
        price = _price;
    }
}
