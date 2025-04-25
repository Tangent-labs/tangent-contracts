// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import "../../../interfaces/internals/tgUSD/IPriceOracle.sol";
import "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";
import "forge-std/console.sol";

struct OracleERC4626Struct {
    IERC4626 erc4626;
    IPriceOracle underlyingOracle;
    uint128 underlyingOracleDecimals;
}

contract OracleERC4626 is IPriceOracle {
    OracleERC4626Struct public params;
    constructor(IERC4626 _erc4626, IPriceOracle _underlyingOracle) {
        params = OracleERC4626Struct({erc4626: _erc4626, underlyingOracle: _underlyingOracle, underlyingOracleDecimals: _underlyingOracle.decimals()});
    }

    function latestAnswer() external view returns (uint256) {
        OracleERC4626Struct memory _params = params;

        uint256 underlyingPrice = _params.underlyingOracle.latestAnswer() * 10 ** (18 - _params.underlyingOracleDecimals);
        return (_params.erc4626.convertToAssets(1e18) * underlyingPrice) / 1e18;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }
}
