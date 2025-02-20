// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IRParams, RCParams, IIRCalculator} from "../../interfaces/internals/tgUSD/IIRCalculator.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import {IAggregatorStablePriceV3} from "../../interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";
import {IDebtIR} from "../../interfaces/internals/tgUSD/IDebtIR.sol";
import {ABDKMath64x64} from "../../libs/ABDKMath64x64.sol";

import "forge-std/console.sol";

///@notice Contract allowing to compute the interest rate and reward cut of a tgUSD market
// TODO Put a cap on tgUSD price to prevent overflow on IR computation
// TODO Comments are bad
contract IRCalculator is IIRCalculator, Ownable {
    uint256 public constant DENOMINATOR = 100_000;

    uint256 public constant ONE_ETHER = 1e18;

    IControlTower public controlTower;

    /// @notice Contract allowing to retrieve the price in dollar of tgUSD.
    IAggregatorStablePriceV3 public tgUSDOracle;

    /// @notice Gives the parameter of the market
    mapping(address => IRParams) public irParams;

    /// @notice Gives the parameter of the market
    mapping(address => RCParams) public rcParams;

    error IRStartPriceLtOne();
    error CallerNotOwnerOrMarketCreator(address caller);

    constructor(address _owner, IControlTower _controlTower, IAggregatorStablePriceV3 _tgUSDOracle) Ownable(_owner) {
        controlTower = _controlTower;
        tgUSDOracle = _tgUSDOracle;
    }

    modifier verifyIRParams(IRParams calldata _irParam) {
        //TODO Add check for params
        // require(_irParam.irStartPrice <= ONE_ETHER, IRStartPriceLtOne());
        _;
    }

    modifier verifyRCParams(RCParams calldata _rcParam) {
        require(_rcParam.startCutPrice <= ONE_ETHER);
        if (_rcParam.stepAmount == 2) {
            require(_rcParam.startCutPercentage < _rcParam.endCutPercentage);
            require(_rcParam.startCutPrice > _rcParam.endCutPrice);
        }
        _;
    }

    function setTgUSDOracle(IAggregatorStablePriceV3 _tgUSDOracle) external onlyOwner {
        tgUSDOracle = _tgUSDOracle;
    }

    function setUpMarket(address market, IRParams calldata _irParam, RCParams calldata _rcParam) external verifyIRParams(_irParam) verifyRCParams(_rcParam) {
        require(msg.sender == owner() || controlTower.isMarketCreator(msg.sender), CallerNotOwnerOrMarketCreator(msg.sender));
        irParams[market] = _irParam;
        rcParams[market] = _rcParam;
        IDebtIR(market).checkpointIR();
    }

    function updateIRParams(address market, IRParams calldata _irParam) external verifyIRParams(_irParam) onlyOwner {
        irParams[market] = _irParam;
        IDebtIR(market).checkpointIR();
    }

    function updateRCParams(address market, RCParams calldata _rcParam) external verifyRCParams(_rcParam) onlyOwner {
        rcParams[market] = _rcParam;
    }

    /**
     * @notice Computes the intest rate regarding the tgUSD price and parameters sigma and r0 from the market
     * @param  market Denominator of the number in exponent. The higher it is, the
     */
    function computeIRForMarket(address market) external returns (uint256) {
        return _computeIR(tgUSDOracle.price_w(), irParams[market]);
    }

    /**
     * @notice Computes the intest rate regarding the tgUSD price and parameters sigma and r0 from the market
     * @param  tgUSDPrice   Price of tgUSD in wei on 18 decimals.
     * @param  irParam      IR parameters
     */
    function simulateIR(uint256 tgUSDPrice, IRParams memory irParam) external view returns (uint256) {
        return _computeIR(tgUSDPrice, irParam);
    }

    function _pow(int128 a, int128 b) internal pure returns (int128) {
        return ABDKMath64x64.exp_2(ABDKMath64x64.mul(ABDKMath64x64.log_2(a), b));
    }
    /**
     * @notice Computes the intest rate regarding the tgUSD price and parameters sigma and r0 from the market
     * @param  tgUSDPrice Price of tgUSD in wei.
     * @param  irParam    IR parameters
     */
    function _computeIR(uint256 tgUSDPrice, IRParams memory irParam) internal view returns (uint256) {
        uint256 nomalizedPMin = uint256(irParam.pMin) * 10 ** 13;
        uint256 nomalizedPMax = uint256(irParam.pMax) * 10 ** 13;
        if (tgUSDPrice < nomalizedPMin) {
            return uint256(irParam.rMax) * 10 ** 13;
        }
        if (tgUSDPrice > nomalizedPMax) {
            return uint256(irParam.rMin) * 10 ** 13;
        }

        int128 gammaX = int128(int32(irParam.k) * (int256(tgUSDPrice) - int32(irParam.pInf) * int256(10 ** 13)));

        // console.log("gammaParam", ABDKMath64x64.toUInt(ABDKMath64x64.mul(gammaX, ABDKMath64x64.fromUInt(100_000))));

        int128 exp = ABDKMath64x64.exp(gammaX);

        // console.log("exp", ABDKMath64x64.toUInt(ABDKMath64x64.mul(exp, ABDKMath64x64.fromUInt(100_000))));

        int128 gamma = ABDKMath64x64.div(ABDKMath64x64.fromUInt(1), ABDKMath64x64.fromUInt(1) + exp);

        console.log("gamma", ABDKMath64x64.toUInt(ABDKMath64x64.mul(gamma, ABDKMath64x64.fromUInt(100_000))));

        int128 alpha = ABDKMath64x64.add(ABDKMath64x64.fromUInt(irParam.a1), ABDKMath64x64.mul(ABDKMath64x64.fromUInt((irParam.a2 - irParam.a1)), gamma));

        console.log("alpha", ABDKMath64x64.toUInt(ABDKMath64x64.mul(alpha, ABDKMath64x64.fromUInt(100_000))));

        uint256 quotient = ((uint256(irParam.pMax) * 10 ** 13) - tgUSDPrice) / (irParam.pMax - irParam.pMin);

        // console.log("quotient", quotient);
        int128 quotientFixedPoint = ABDKMath64x64.divu(quotient, 10 ** 13);

        int128 priceRatio = _pow(quotientFixedPoint, alpha);

        // console.log("priceRatio", ABDKMath64x64.toUInt(ABDKMath64x64.mul(priceRatio, ABDKMath64x64.fromUInt(100_000))));

        int128 irIncrement = ABDKMath64x64.mul(ABDKMath64x64.fromUInt(uint256(irParam.rMax - irParam.rMin) * 10 ** 8), priceRatio);

        // console.log("irIncrement", ABDKMath64x64.toUInt(ABDKMath64x64.mul(irIncrement, ABDKMath64x64.fromUInt(100_000))));

        return uint256(irParam.rMin) * 10 ** 13 + ABDKMath64x64.toUInt(ABDKMath64x64.mul(irIncrement, ABDKMath64x64.fromUInt(100_000)));
    }

    // function _computeIR(uint256 tgUSDPrice, IRParams calldata irParam) internal view returns (uint256) {
    //     if (tgUSDPrice > irStartPrice) {
    //         return 0;
    //     }
    //     if (tgUSDPrice < priceIRMax) {
    //         tgUSDPrice = priceIRMax;
    //     }

    //     int128 powerIn64x64 = ABDKMath64x64.divu(((1 ether - tgUSDPrice) * ONE_ETHER) / sigma, ONE_ETHER);

    //     // Calcul exp(1) en utilisant la méthode exp
    //     int128 expIn64x64 = ABDKMath64x64.exp(powerIn64x64);

    //     // Integer part of exp result
    //     uint256 integerPart = ABDKMath64x64.toUInt(expIn64x64);

    //     // Decimal part of the exp in uint256
    //     uint256 fractionalAsDecimal = ABDKMath64x64.mulu(expIn64x64 - ABDKMath64x64.fromUInt(integerPart), ONE_ETHER);

    //     uint256 formulaReturn = integerPart * ONE_ETHER + fractionalAsDecimal;

    //     return (formulaReturn * r0) / ONE_ETHER;
    // }

    /**
     * @notice Computes the intest rate regarding the tgUSD price and parameters sigma and r0 from the market
     * @param  market Denominator of the number in exponent. The higher it is, the
     */
    function computeRCForMarket(address market) external returns (uint256) {
        RCParams memory rcParam = rcParams[market];
        return _calculateRC(tgUSDOracle.price_w(), rcParam.stepAmount, rcParam.startCutPercentage, rcParam.endCutPercentage, rcParam.startCutPrice, rcParam.endCutPrice);
    }

    /**
     * @notice Computes the intest rate regarding the tgUSD price and parameters sigma and r0 from the market
     * @param  tgUSDPrice Denominator of the number in exponent. The higher it is, the
     * @param  stepAmount    New sociabilization fee on a 100_000 basis
     * @param  startCutPercentage Denominator of the number in exponent. The higher it is, the
     * @param  endCutPercentage    New sociabilization fee on a 100_000 basis
     * @param  startCutPrice    New sociabilization fee on a 100_000 basis
     * @param  endCutPrice    New sociabilization fee on a 100_000 basis
     */
    function simulateRC(
        uint256 tgUSDPrice,
        uint16 stepAmount,
        uint32 startCutPercentage,
        uint32 endCutPercentage,
        uint88 startCutPrice,
        uint88 endCutPrice
    ) external pure returns (uint256) {
        return _calculateRC(tgUSDPrice, stepAmount, startCutPercentage, endCutPercentage, startCutPrice, endCutPrice);
    }

    /**
     * @notice Computes the reward cut percentage based on the tgUSD price and market parameters
     * @param  tgUSDPrice Price of tgUSD in wei.
     * @param  stepAmount Number of distinct reward cut steps.
     * @param  startCutPercentage Percentage of the reward cut at the start.
     * @param  endCutPercentage Maximum percentage of the reward cut.
     * @param  startCutPrice Price of tgUSD at which the reward cut starts to increase.
     * @param  endCutPrice Price of tgUSD at which the reward cut is at its maximum.
     */
    function _calculateRC(
        uint256 tgUSDPrice,
        uint16 stepAmount,
        uint32 startCutPercentage,
        uint32 endCutPercentage,
        uint88 startCutPrice,
        uint88 endCutPrice
    ) internal pure returns (uint256) {
        // Cut percentage is always constant
        if (stepAmount == 1) {
            return startCutPercentage;
        }
        // Cut percentage either startCutPercentage or endCutPercetange
        else if (stepAmount == 2) {
            if (tgUSDPrice >= startCutPrice) {
                return startCutPercentage;
            } else {
                return endCutPercentage;
            }
        }
        // Cut percentage is computed regarding the step amount
        else {
            // When tgUSDPrice is above the startCutPrice
            if (tgUSDPrice >= startCutPrice) {
                return startCutPercentage;
            }
            if (tgUSDPrice < endCutPrice) {
                return endCutPercentage;
            }
            uint256 stepsBetween = stepAmount - 2;
            uint256 actualStep = 1 + (startCutPrice - tgUSDPrice) / ((startCutPrice - endCutPrice) / stepsBetween);
            return startCutPercentage + (actualStep * (endCutPercentage - startCutPercentage)) / stepsBetween;
        }
    }
}
