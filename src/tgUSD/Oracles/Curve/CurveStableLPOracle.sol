// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../../interfaces/internals/tgUSD/IPriceOracle.sol";
import "../../../interfaces/externals/Curve/ICurveStableSwapNG.sol";
import "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";

import "forge-std/console.sol";

contract CurveStableLPOracle is IPriceOracle {
    mapping(address => uint256) curveLPType;

    IERC20Metadata coin0;
    IERC20Metadata coin1;

    IPriceOracle coin0Oracle;
    IPriceOracle coin1Oracle;

    uint256 coin0Decimals;
    uint256 coin1Decimals;

    uint256 coin0OracleDecimals;
    uint256 coin1OracleDecimals;

    ICurveStableSwapNG lp;

    constructor(ICurveStableSwapNG _lp, IPriceOracle _coin0Oracle, IPriceOracle _coin1Oracle) {
        lp = _lp;

        IERC20Metadata _coin0 = IERC20Metadata(_lp.coins(0));
        coin0 = _coin0;
        coin0Decimals = _coin0.decimals();

        IERC20Metadata _coin1 = IERC20Metadata(_lp.coins(1));
        coin1 = _coin1;
        coin1Decimals = _coin1.decimals();

        coin0Oracle = _coin0Oracle;
        coin1Oracle = _coin1Oracle;

        coin0OracleDecimals = _coin0Oracle.decimals();
        coin1OracleDecimals = _coin1Oracle.decimals();
    }

    function decimals() external pure returns (uint256) {
        return 18;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) {
            return b;
        }

        return a;
    }

    function latestAnswer() external view returns (uint256) {
        // (, int256 a0, , uint256 lastUpdate0, ) = coin0Oracle.latestRoundData();
        // (, int256 a1, , uint256 lastUpdate1, ) = coin1Oracle.latestRoundData();

        uint256 a0 = coin0Oracle.latestAnswer();
        uint256 a1 = coin1Oracle.latestAnswer();

        uint256 answer0 = uint256(a0) * 10 ** (18 - coin0OracleDecimals);
        uint256 answer1 = uint256(a1) * 10 ** (18 - coin1OracleDecimals);

        return (lp.get_virtual_price() * min(uint256(answer0), uint256(answer1))) / 10 ** 18;
    }
}
