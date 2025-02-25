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

    uint256 constant ONE_ETHER = 1e18;

    uint256 constant E12 = 1e12;
    uint256 constant E13 = 1e13;

    int256 constant MAX_EXP = 43;

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
        if (tgUSDPrice <= uint256(irParam.pMin) * E12) {
            return uint256(irParam.rMax) * E13;
        }
        if (tgUSDPrice >= uint256(irParam.pMax) * E12) {
            return uint256(irParam.rMin) * E13;
        }

        // x to pass in the σ(x) function, with x = k . (actualPrice - pInflexion)
        int128 sigmaX = -ABDKMath64x64.mul(
            ABDKMath64x64.fromUInt(irParam.k),
            ABDKMath64x64.divi(int256(tgUSDPrice) - int256(int32(irParam.pInf)) * int256(E12), int256(ONE_ETHER))
        );
        // To prevent exp overflow
        if (ABDKMath64x64.toInt(sigmaX) >= MAX_EXP) {
            sigmaX = ABDKMath64x64.fromInt(MAX_EXP);
        }
        int128 one = ABDKMath64x64.fromUInt(1);
        // σ(x) image with σ(x) = 1 / (1 + exp(-x)) and -x = sigmaX.
        int128 sigma = ABDKMath64x64.div(one, one + ABDKMath64x64.exp(sigmaX));
        int128 alpha1 = ABDKMath64x64.divu(irParam.a1, 1_000);

        // α(x) image with α(x) = α1 + (α2 - α1).σ(x)
        int128 alpha = ABDKMath64x64.add(alpha1, ABDKMath64x64.mul(ABDKMath64x64.sub(ABDKMath64x64.divu(irParam.a2, 1_000), alpha1), sigma));

        // Relative delta beween pMax, pMin and actual Price
        // quotient = (pMax - actualPrice) / (pMax - pMin )
        int128 quotientFixedPoint = ABDKMath64x64.divu(((uint256(irParam.pMax) * E12) - tgUSDPrice) / (irParam.pMax - irParam.pMin), E12);

        // Computes the IR to increment to the minimum IR possible on the market.
        // irIncr = (rMax - rMin) * ((pMax - actualPrice) / (pMax - pMin))^alpha

        uint256 irIncrement = ABDKMath64x64.mulu(ABDKMath64x64.mul(ABDKMath64x64.fromUInt(irParam.rMax - irParam.rMin), _pow(quotientFixedPoint, alpha)), E13);

        return uint256(irParam.rMin) * E13 + irIncrement;
    }

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
