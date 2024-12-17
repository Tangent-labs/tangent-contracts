// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IIrCalculator} from "../../interfaces/internals/tgUSD/IIrCalculator.sol";
import {IPriceOracle} from "../../interfaces/internals/tgUSD/IPriceOracle.sol";
import {IDebtIR} from "../../interfaces/internals/tgUSD/IDebtIR.sol";
import {ABDKMath64x64} from "../../libs/ABDKMath64x64.sol";

import "forge-std/console.sol";

contract IRCalculator is IIrCalculator, Ownable {
    uint256 public constant DENOMINATOR = 100_000;

    /// @notice Contract allowing to retrieve the price in dollar of tgUSD.
    IPriceOracle public tgUSDOracle;

    /// @notice Gives the parameter of the market
    mapping(address => IRParams) public irParams;

    /// @notice Gives the parameter of the market
    mapping(address => RCParams) public rcParams;

    struct IRParams {
        uint128 sigma;
        uint128 r0;
        uint256 irStartPrice;
    }

    struct RCParams {
        uint64 cutAtOneDollar;
        uint64 stepAmount;
        uint128 fullCutPrice;
    }

    constructor(address _owner, IPriceOracle _tgUSDOracle) Ownable(_owner) {
        tgUSDOracle = _tgUSDOracle;
    }

    function setUpMarketRewards(address market, IRParams calldata _irParam, RCParams calldata _rcParam) external onlyOwner {
        irParams[market] = _irParam;
        rcParams[market] = _rcParam;
        IDebtIR(market).checkpointIR();
    }

    function updateIR(address market, IRParams calldata _irParam) external onlyOwner {
        irParams[market] = _irParam;
        IDebtIR(market).checkpointIR();
    }

    function updateRC(address market, RCParams calldata _rcParam) external onlyOwner {
        rcParams[market] = _rcParam;
    }

    /**
     * @notice Computes the intest rate regarding the tgUSD price and parameters sigma and r0 from the market
     * @param  market Denominator of the number in exponent. The higher it is, the
     */
    function computeIRForMarket(address market) external view returns (uint256) {
        IRParams memory irParam = irParams[market];
        return _computeIR(tgUSDOracle.latestAnswer(), irParam.sigma, irParam.r0, irParam.irStartPrice);
    }

    /**
     * @notice Computes the intest rate regarding the tgUSD price and parameters sigma and r0 from the market
     * @param  tgUSDPrice a
     * @param  sigma a
     * @param  r0    a
     */
    function simulateIR(uint256 tgUSDPrice, uint256 sigma, uint256 r0, uint256 irStartPrice) external pure returns (uint256) {
        return _computeIR(tgUSDPrice, sigma, r0, irStartPrice);
    }
    /**
     * @notice Computes the intest rate regarding the tgUSD price and parameters sigma and r0 from the market
     * @param  tgUSDPrice Price of tgUSD in wei.
     * @param  sigma Denominator of the part passed to exp. The smaller it is, the faster the IR grows with depeg
     * @param  r0   Base coefficient of the IR
     */
    function _computeIR(uint256 tgUSDPrice, uint256 sigma, uint256 r0, uint256 irStartPrice) internal pure returns (uint256) {
        if (tgUSDPrice > irStartPrice) {
            return 0;
        }
        int128 powerIn64x64 = ABDKMath64x64.divu(((1 ether - tgUSDPrice) * 10 ** 18) / sigma, 10 ** 18);

        // Calcul exp(1) en utilisant la méthode exp
        int128 expIn64x64 = ABDKMath64x64.exp(powerIn64x64);

        // Integer part of exp result
        uint256 integerPart = ABDKMath64x64.toUInt(expIn64x64);

        // Decimal part of the exp in uint256
        uint256 fractionalAsDecimal = ABDKMath64x64.mulu(expIn64x64 - ABDKMath64x64.fromUInt(integerPart), 10 ** 18);

        uint256 formulaReturn = integerPart * 10 ** 18 + fractionalAsDecimal;

        return (formulaReturn * r0) / 1 ether;
    }

    /**
     * @notice Computes the intest rate regarding the tgUSD price and parameters sigma and r0 from the market
     * @param  market Denominator of the number in exponent. The higher it is, the
     */
    function computeRCForMarket(address market) external view returns (uint256) {
        RCParams memory rcParam = rcParams[market];
        return _calculateRC(tgUSDOracle.latestAnswer(), rcParam.cutAtOneDollar, rcParam.stepAmount, rcParam.fullCutPrice);
    }

    /**
     * @notice Computes the intest rate regarding the tgUSD price and parameters sigma and r0 from the market
     * @param  tgUSDPrice Denominator of the number in exponent. The higher it is, the
     * @param  cutAtOneDollar Denominator of the number in exponent. The higher it is, the
     * @param  stepAmount    New sociabilization fee on a 100_000 basis
     */
    function simulateRC(uint256 tgUSDPrice, uint64 cutAtOneDollar, uint64 stepAmount, uint128 fullCutPrice) external pure returns (uint256) {
        return _calculateRC(tgUSDPrice, cutAtOneDollar, stepAmount, fullCutPrice);
    }

    function _calculateRC(uint256 tgUSDPrice, uint64 cutAtOneDollar, uint64 stepAmount, uint128 fullCutPrice) internal pure returns (uint256) {
        uint256 stepPrice = (1e18 - fullCutPrice) / stepAmount;

        uint256 aa = 1 + (1e18 - tgUSDPrice) / stepPrice;
        uint256 rewardCut = cutAtOneDollar + aa * stepAmount;
        return rewardCut;
    }
}
