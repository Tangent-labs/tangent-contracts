// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../../interfaces/internals/tgUSD/IPriceOracle.sol";
import "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";

import "forge-std/console.sol";

contract OracleDuoPoolStable is IPriceOracle {
    struct OracleDuoPoolStruct {
        IPriceOracle coin0Oracle;
        IPriceOracle coin1Oracle;
        ICurveStableSwapNG lp;
        uint16 coin0OracleDecimals;
        uint16 coin1OracleDecimals;
    }

    OracleDuoPoolStruct public params;

    constructor(ICurveStableSwapNG _lp, IPriceOracle _coin0Oracle, IPriceOracle _coin1Oracle) {
        params = OracleDuoPoolStruct({
            coin0Oracle: _coin0Oracle,
            coin1Oracle: _coin1Oracle,
            lp: _lp,
            coin0OracleDecimals: uint16(_coin0Oracle.decimals()),
            coin1OracleDecimals: uint16(_coin1Oracle.decimals())
        });
    }

    function decimals() external pure returns (uint256) {
        return 18;
    }

    function coinPrice(IPriceOracle _oracle, uint256 oracleDecimals) internal view returns (uint256) {
        return _oracle.latestAnswer() * 10 ** (18 - oracleDecimals);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return b;
        }
        return a;
    }

    function latestAnswer() external view returns (uint256) {
        OracleDuoPoolStruct memory _params = params;
        uint256 answer0 = coinPrice(_params.coin0Oracle, _params.coin0OracleDecimals);
        uint256 answer1 = coinPrice(_params.coin1Oracle, _params.coin1OracleDecimals);

        return (_params.lp.get_virtual_price() * min(answer0, answer1)) / 10 ** 18;
    }
}
