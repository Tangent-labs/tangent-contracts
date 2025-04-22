// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../../../interfaces/internals/tgUSD/IPriceOracle.sol";
import "../../../interfaces/externals/Curve/ICurveTriCryptoSwap.sol";
import "../../../interfaces/externals/Chainlink/IAggregatorV3.sol";

import "forge-std/console.sol";

contract OracleCryptoSwap is IPriceOracle {
    struct OracleCryptoSwapStruct {
        ICurveTriCryptoSwap lp;
        IPriceOracle coin0Oracle;
        uint192 coin0OracleDecimals;
    }
    OracleCryptoSwapStruct public params;

    constructor(ICurveTriCryptoSwap _lp, IPriceOracle coin0Oracle) {
        params = OracleCryptoSwapStruct({lp: _lp, coin0Oracle: coin0Oracle, coin0OracleDecimals: uint192(coin0Oracle.decimals())});
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    /**
     * @notice Internal function to get the latest price from an oracle
     * @param _oracle The oracle to get the price from
     * @param oracleDecimals The number of decimals used by the oracle
     * @return The latest price from the oracle, adjusted to 18 decimals
     */
    function _coinPrice(IPriceOracle _oracle, uint256 oracleDecimals) internal view returns (uint256) {
        return _oracle.latestAnswer() * 10 ** (18 - oracleDecimals);
    }

    function latestAnswer() external view returns (uint256) {
        OracleCryptoSwapStruct memory _params = params;

        return (_params.lp.lp_price() * _coinPrice(_params.coin0Oracle, _params.coin0OracleDecimals)) / 1e18;
    }
}
