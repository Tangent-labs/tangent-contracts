// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {LightOwnable} from "../Utilities/abstract/LightOwnable.sol";

import {IRParams, IIRCalculator, IRCheckpoint} from "../../interfaces/internals/tgUSD/IIRCalculator.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import {IAggregatorStablePriceV3} from "../../interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";
import {IDebtIR} from "../../interfaces/internals/tgUSD/IDebtIR.sol";
import {ITgUSD} from "../../interfaces/internals/tgUSD/ITgUSD.sol";

import {ABDKMath64x64} from "../../libs/ABDKMath64x64.sol";

import "forge-std/console.sol";

///@notice Contract allowing to compute the interest rate and reward cut of a tgUSD market
// TODO Put a cap on tgUSD price to prevent overflow on IR computation
// TODO Comments are bad
contract IRCalculator is IIRCalculator, LightOwnable {
    uint256 public constant DENOMINATOR = 100_000;

    uint256 constant RAY = 1e27;
    uint256 constant ONE_ETHER = 1e18;

    uint256 constant E12 = 1e12;
    uint256 constant E13 = 1e13;

    int256 constant MAX_EXP = 43;

    IControlTower public controlTower;

    /// @notice Contract allowing to retrieve the price in dollar of tgUSD.
    IAggregatorStablePriceV3 public tgUSDOracle;

    ITgUSD public tgUSD;

    /// @notice Interests from loan are accumulated in this value on each _checkpointIR.
    uint256 public mintableInterests;

    /// @notice Gives the parameter of the market
    mapping(address => IRParams) public irParams;

    /// @notice Last interest rate since previous interaction with the market. In RAY.
    mapping(address => IRCheckpoint) public irCheckpoints;

    mapping(address => uint256) public debtIndexes;

    error IRStartPriceLtOne();
    error CallerNotMarketCreator();
    error NotAMarket();
    error A1TooBig();
    error A2TooBig();
    error KTooBig();
    error RMaxTooBig();
    error RMinBiggerThanRMax();
    error PMinBiggerThanPInf();
    error PInfBiggerThanPMax();
    error PMaxBiggerThanOneDollar();

    event CheckpointIR(address indexed market, uint256 irAmount, uint256 newIndex);

    constructor(address _owner, IControlTower _controlTower, IAggregatorStablePriceV3 _tgUSDOracle, ITgUSD _tgUSD) {
        controlTower = _controlTower;
        tgUSDOracle = _tgUSDOracle;
        tgUSD = _tgUSD;
        _transferOwnership(_owner);
    }

    function _verifyIRParams(IRParams calldata _irParam) internal pure {
        require(_irParam.a1 <= 20_000, A1TooBig());
        require(_irParam.a2 <= 20_000, A2TooBig());
        require(_irParam.k <= 20_000, KTooBig());
        require(_irParam.rMax <= 400_000, RMaxTooBig());
        require(_irParam.rMin <= _irParam.rMax, RMinBiggerThanRMax());
        require(_irParam.pMin <= _irParam.pInf, PMinBiggerThanPInf());
        require(_irParam.pInf <= _irParam.pMax, PInfBiggerThanPMax());
        require(_irParam.pMax <= 1_000_000, PMaxBiggerThanOneDollar());
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        OWNER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function setTgUSDOracle(IAggregatorStablePriceV3 _tgUSDOracle) external onlyOwner {
        tgUSDOracle = _tgUSDOracle;
    }

    function initializeMarket(address market, IRParams calldata _irParams) external {
        _verifyIRParams(_irParams);
        require(controlTower.isMarketCreator(msg.sender), CallerNotMarketCreator());
        debtIndexes[market] = RAY;
        irParams[market] = _irParams;

        irCheckpoints[market] = IRCheckpoint({ir: _computeIR(tgUSDOracle.price_w(), _irParams), timestamp: uint40(block.timestamp)});
    }

    function updateIRParams(address market, IRParams calldata _irParam) external onlyOwner {
        _verifyIRParams(_irParam);
        irParams[market] = _irParam;
        _checkpointIR(market);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    IR COMPUTATION
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Computes the intest rate regarding the tgUSD price and parameters of the market
     * @param  market address of the market
     */
    function computeIRForMarket(address market) public returns (uint256) {
        return _computeIR(tgUSDOracle.price_w(), irParams[market]);
    }

    function getIRParams(address market) external view returns (IRParams memory) {
        return irParams[market];
    }

    function getIRCheckpoint(address market) external view returns (IRCheckpoint memory) {
        return irCheckpoints[market];
    }

    /**
     * @notice Computes the intest rate regarding the tgUSD price and parameters sigma and r0 from the market
     * @param  tgUSDPrice   Price of tgUSD in wei on 18 decimals.
     * @param  irParam      IR parameters
     */
    function simulateIR(uint256 tgUSDPrice, IRParams memory irParam) external pure returns (uint256) {
        return _computeIR(tgUSDPrice, irParam);
    }

    /**
     * @notice Computes the intest rate regarding the tgUSD price and parameters sigma and r0 from the market
     * @param  tgUSDPrice Price of tgUSD in wei.
     * @param  irParam    IR parameters
     */
    function _computeIR(uint256 tgUSDPrice, IRParams memory irParam) internal pure returns (uint216) {
        if (tgUSDPrice <= uint256(irParam.pMin) * E12) {
            return uint216(irParam.rMax * E13);
        }
        if (tgUSDPrice >= uint256(irParam.pMax) * E12) {
            if (irParam.isHEC) {
                return 0;
            }
            return uint216(irParam.rMin * E13);
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

        return uint216(uint256(irParam.rMin) * E13 + irIncrement);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    DEBT INDEX COMPUTATION
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    // newIndex = oldIndex * exp(ir * timeRatio)
    function simulateNewDebtIndex(uint256 oldIndex, IRCheckpoint memory _checkpoint) external view returns (uint256) {
        return _computeNewDebtIndex(oldIndex, _checkpoint);
    }

    function newDebtIndex(address market) external view returns (uint256) {
        IRCheckpoint memory _irCheckpoint = irCheckpoints[market];
        return _computeNewDebtIndex(debtIndexes[market], _irCheckpoint);
    }

    function indexDelta(address market) external view returns (uint256) {
        uint256 oldIndex = debtIndexes[market];
        return _computeNewDebtIndex(oldIndex, irCheckpoints[market]) - oldIndex;
    }

    /**
     *  @notice Computes and returns the new debt index regarding interests generated allowing to readjust the total debt of the market
     *          If some interests are generated, it increments the value in tgUSD to be able to mint them later.
     *  @dev    Example :
     *                    - On a market with 2M debt with 10% interests on 6 month
     *                    - IndexIncrease = 0.1 * 6 month / 1 year = 5%
     *                    - Interest Generated = 2M * 5% = 100 000
     */
    function checkpointIR(address market) external returns (uint256) {
        return _checkpointIR(market);
    }

    function _checkpointIR(address market) internal returns (uint256) {
        require(controlTower.isMarket(market), NotAMarket());

        IRCheckpoint memory _irCheckpoint = irCheckpoints[market];

        irCheckpoints[market] = IRCheckpoint({ir: _computeIR(tgUSDOracle.price_w(), irParams[market]), timestamp: uint40(block.timestamp)});

        uint256 oldIndex = debtIndexes[market];

        uint256 newIndex = _computeNewDebtIndex(oldIndex, _irCheckpoint);

        uint256 interests = (IDebtIR(market).totalDebtShares() * (newIndex - oldIndex)) / RAY;
        if (interests != 0) {
            mintableInterests += interests;
        }

        debtIndexes[market] = newIndex;
        emit CheckpointIR(market, interests, newIndex);

        return newIndex;
    }

    /**
     *  @notice Computes and returns the new debt index regarding interests generated allowing to readjust the total debt of the market
     *          If some interests are generated, it increments the value in tgUSD to be able to mint them later.
     *  @dev    Example :
     *                    - On a market with 2M debt with 10% interests on 6 month
     *                    - IndexIncrease = 0.1 * 6 month / 1 year = 5%
     *                    - Interest Generated = 2M * 5% = 100 000
     */
    function checkpointIRMulti(address[] calldata markets) external {
        require(controlTower.areContractsMarkets(markets), NotAMarket());

        uint256 newTgUSDPrice = tgUSDOracle.price_w();
        uint40 ts = uint40(block.timestamp);

        uint256 _mintableInterests;
        for (uint256 i; i < markets.length; ) {
            address market = markets[i];
            IRCheckpoint memory _irCheckpoint = irCheckpoints[market];

            irCheckpoints[market] = IRCheckpoint({ir: _computeIR(newTgUSDPrice, irParams[market]), timestamp: ts});

            uint256 oldIndex = debtIndexes[market];
            uint256 newIndex = _computeNewDebtIndex(oldIndex, _irCheckpoint);

            uint256 interests = (IDebtIR(market).totalDebtShares() * (newIndex - oldIndex)) / RAY;

            if (interests != 0) {
                _mintableInterests += interests;
            }
            emit CheckpointIR(market, interests, newIndex);

            debtIndexes[market] = newIndex;

            unchecked {
                ++i;
            }
        }
        mintableInterests += _mintableInterests;
    }

    function mintIR() external {
        uint256 _mintableInterests = mintableInterests;
        delete mintableInterests;
        tgUSD.mintIR(_mintableInterests);
    }

    // newIndex = oldIndex * exp(ir * timeRatio)
    function _computeNewDebtIndex(uint256 oldIndex, IRCheckpoint memory _checkpoint) internal view returns (uint256) {
        uint256 timeDelta = block.timestamp - _checkpoint.timestamp;
        if (timeDelta == 0) {
            return oldIndex;
        }

        int128 expContent = ABDKMath64x64.mul(ABDKMath64x64.divu(_checkpoint.ir, ONE_ETHER), ABDKMath64x64.divu(timeDelta, 365 days));

        // To prevent exp overflow
        if (ABDKMath64x64.toInt(expContent) >= MAX_EXP) {
            expContent = ABDKMath64x64.fromInt(MAX_EXP);
        }

        return (ABDKMath64x64.mulu(ABDKMath64x64.exp(expContent), RAY) * oldIndex) / RAY;
    }

    function _pow(int128 a, int128 b) internal pure returns (int128) {
        return ABDKMath64x64.exp_2(ABDKMath64x64.mul(ABDKMath64x64.log_2(a), b));
    }
}
