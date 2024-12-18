// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../../interfaces/internals/tgUSD/IPriceOracle.sol";
import "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";

import "forge-std/console.sol";

contract OracleTriPoolStable is IPriceOracle {
    struct OracleTriPoolStruct {
        IPriceOracle coin0Oracle;
        IPriceOracle coin1Oracle;
        IPriceOracle coin2Oracle;
        ICurveStableSwapNG lp;
        uint40 coin0OracleDecimals;
        uint40 coin1OracleDecimals;
        uint48 coin2OracleDecimals;
    }
    OracleTriPoolStruct public params;

    constructor(ICurveStableSwapNG _lp, IPriceOracle _coin0Oracle, IPriceOracle _coin1Oracle, IPriceOracle _coin2Oracle) {
        params = OracleTriPoolStruct({
            coin0Oracle: _coin0Oracle,
            coin1Oracle: _coin1Oracle,
            coin2Oracle: _coin2Oracle,
            lp: _lp,
            coin0OracleDecimals: uint40(_coin0Oracle.decimals()),
            coin1OracleDecimals: uint40(_coin1Oracle.decimals()),
            coin2OracleDecimals: uint48(_coin2Oracle.decimals())
        });
    }

    function decimals() external pure returns (uint256) {
        return 18;
    }

    function min(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        // b is smaller than a
        if (a > b) {
            // c is smaller than b
            if (b > c) {
                return c;
            }
            return b;
        }
        // a is smaller than b
        else {
            // c is smaller than a
            if (a > c) {
                return c;
            }
            return a;
        }
    }

    function latestAnswer() external view returns (uint256) {
        OracleTriPoolStruct memory _params = params;
        uint256 answer0 = uint256(_params.coin0Oracle.latestAnswer()) * 10 ** (18 - _params.coin0OracleDecimals);
        uint256 answer1 = uint256(_params.coin1Oracle.latestAnswer()) * 10 ** (18 - _params.coin1OracleDecimals);
        uint256 answer2 = uint256(_params.coin2Oracle.latestAnswer()) * 10 ** (18 - _params.coin2OracleDecimals);

        return (_params.lp.get_virtual_price() * min(answer0, answer1, answer2)) / 10 ** 18;
    }
}
