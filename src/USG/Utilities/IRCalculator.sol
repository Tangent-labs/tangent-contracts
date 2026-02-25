// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {LightReentrancyGuardTransient} from "../Utilities/abstract/LightReentrancyGuardTransient.sol";

import {LightOwnable} from "../Utilities/abstract/LightOwnable.sol";

import {IRParams, IIRCalculator, IRCheckpoint} from "../../interfaces/internals/USG/IIRCalculator.sol";
import {IControlTower} from "../../interfaces/internals/USG/IControlTower.sol";
import {IAggregatorStablePriceV3} from "../../interfaces/externals/LlamaLend/IAggregatorStablePriceV3.sol";
import {IDebtIR} from "../../interfaces/internals/USG/IDebtIR.sol";
import {IUSG} from "../../interfaces/internals/USG/IUSG.sol";

import {ABDKMath64x64} from "../../libs/ABDKMath64x64.sol";

/// @title IRCalculator
/// @author Tangent Finance
/// @notice Calculates and stores interest rates for all markets.
contract IRCalculator is IIRCalculator, LightOwnable, LightReentrancyGuardTransient {
    uint256 public constant DENOMINATOR = 100_000;

    uint256 constant RAY = 1e27;
    uint256 constant ONE_ETHER = 1e18;

    uint256 constant E12 = 1e12;
    uint256 constant E13 = 1e13;

    int256 constant MAX_EXP = 43;

    IControlTower public controlTower;

    /// @notice Contract allowing to retrieve the price in dollar of USG.
    IAggregatorStablePriceV3 public USGOracle;

    IUSG public USG;

    /// @notice Interests from loan are accumulated in this value on each _checkpointIR.
    uint256 public mintableInterests;

    /// @notice Gives the parameter of the market
    mapping(address => IRParams) public irParams;

    /// @notice Last interest rate and timestamp stored during the last interaction. In RAY.
    mapping(address => IRCheckpoint) public irCheckpoints;

    /// @notice Last debt indexes per market.
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
    error PMinBiggerThanPMax();
    error PMaxBiggerThanOneDollar();

    event CheckpointIR(address indexed market, uint256 irAmount, uint256 newIndex);
    event SetUSGOracle(IAggregatorStablePriceV3 usgOracle);
    event SetIRParams(address market, IRParams _irParam);

    constructor(address _owner, IControlTower _controlTower, IAggregatorStablePriceV3 _USGOracle, IUSG _USG) {
        controlTower = _controlTower;
        USGOracle = _USGOracle;
        USG = _USG;
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
        require(_irParam.pMin < _irParam.pMax, PMinBiggerThanPMax());
        require(_irParam.pMax <= 1_000_000, PMaxBiggerThanOneDollar());
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        OWNER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function setUSGOracle(IAggregatorStablePriceV3 _USGOracle) external onlyOwner {
        USGOracle = _USGOracle;
        emit SetUSGOracle(_USGOracle);
    }

    function initializeMarket(address market, IRParams calldata _irParam) external nonReentrant {
        _verifyIRParams(_irParam);
        require(controlTower.isMarketCreator(msg.sender), CallerNotMarketCreator());
        debtIndexes[market] = RAY;
        irParams[market] = _irParam;
        irCheckpoints[market] = IRCheckpoint({ir: _computeIR(USGOracle.price_w(), _irParam), timestamp: uint40(block.timestamp)});
    }

    /**
     *  @notice Updates the IRParameters for a
     *  @dev    Example :
     *                    - On a market with 2M debt with 10% interests on 6 month
     *                    - IndexIncrease = 0.1 * 6 month / 1 year = 5%
     *                    - Interest Generated = 2M * 5% = 100 000
     *  @param market Market to checkpoint the index for
     */
    function updateIRParams(address market, IRParams calldata _irParam) external nonReentrant onlyOwner {
        _verifyIRParams(_irParam);
        irParams[market] = _irParam;
        _checkpointIR(market);
        emit SetIRParams(market, _irParam);
    }

    /**
     *  @notice Computes and returns the new debt index regarding interests generated allowing to readjust the total debt of the market
     *          If some interests are generated, it increments the value in USG to be able to mint them later.
     *  @dev    Example :
     *                    - On a market with 2M debt with 10% interests on 6 month
     *                    - IndexIncrease = 0.1 * 6 month / 1 year = 5%
     *                    - Interest Generated = 2M * 5% = 100 000
     *  @param market Market to checkpoint the index for
     */
    function checkpointIR(address market) external nonReentrant returns (uint256) {
        return _checkpointIR(market);
    }

    function _checkpointIR(address market) internal returns (uint256) {
        uint256 oldIndex = debtIndexes[market];
        // If the old index is 0, for `market`, it means it has never been initialized
        require(oldIndex != 0, NotAMarket());

        IRCheckpoint memory _irCheckpoint = irCheckpoints[market];
        uint216 newIR;
        // In case price_w fails
        try USGOracle.price_w() returns (uint256 usgPrice) {
            newIR = _computeIR(usgPrice, irParams[market]);
        } catch {
            // Fall back to prior IR if oracle reverts
            newIR = _irCheckpoint.ir;
        }
        irCheckpoints[market] = IRCheckpoint({ir: newIR, timestamp: uint40(block.timestamp)});

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
     *  @notice Computes the new IR on several markets at the same time in an optimized way.
     *  @dev    Retrive only one time the USG price, and increments only once the mintable interests
     *  @param markets Markets to checkpoint the indexes for
     */
    function checkpointIRMulti(address[] calldata markets) external nonReentrant {
        uint256 newUSGPrice;
        bool isSuccess;
        try USGOracle.price_w() returns (uint256 usgPrice) {
            newUSGPrice = usgPrice;
            isSuccess = true;
        } catch {}

        uint40 ts = uint40(block.timestamp);

        uint256 _mintableInterests;
        for (uint256 i; i < markets.length; ) {
            address market = markets[i];
            IRCheckpoint memory _irCheckpoint = irCheckpoints[market];

            // Nominal case, when price_w is not failing
            if (isSuccess) {
                irCheckpoints[market] = IRCheckpoint({ir: _computeIR(newUSGPrice, irParams[market]), timestamp: ts});
            }
            // Else, newUSGPrice failed so we take the previous IR
            else {
                irCheckpoints[market] = IRCheckpoint({ir: _irCheckpoint.ir, timestamp: ts});
            }

            uint256 oldIndex = debtIndexes[market];
            // If the old index is 0, for `market`, it means it has never been initialized
            require(oldIndex != 0, NotAMarket());

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

    function mintIR() external nonReentrant {
        uint256 _mintableInterests = mintableInterests;
        delete mintableInterests;
        USG.mintIR(_mintableInterests);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                    IR COMPUTATION
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Computes the intest rate regarding the USG price and parameters of the market
     * @param  market address of the market
     */
    function computeIRForMarket(address market) public returns (uint256) {
        return _computeIR(USGOracle.price_w(), irParams[market]);
    }

    function getIRParams(address market) external view returns (IRParams memory) {
        return irParams[market];
    }

    function getIRCheckpoint(address market) external view returns (IRCheckpoint memory) {
        return irCheckpoints[market];
    }

    /**
     * @notice Computes the intest rate regarding the USG price and parameters sigma and r0 from the market
     * @param  USGPrice   Price of USG in wei on 18 decimals.
     * @param  irParam      IR parameters
     */
    function simulateIR(uint256 USGPrice, IRParams memory irParam) external pure returns (uint256) {
        return _computeIR(USGPrice, irParam);
    }

    function _returnMinIR(bool isHec, uint24 irMin) internal pure returns (uint216) {
        if (isHec) {
            return 0;
        }
        return uint216(irMin * E13);
    }

    /**
     * @notice Computes the intest rate regarding the USG price and parameters sigma and r0 from the market
     * @param  USGPrice Price of USG in wei.
     * @param  irParam    IR parameters
     */
    function _computeIR(uint256 USGPrice, IRParams memory irParam) internal pure returns (uint216) {
        if (USGPrice <= uint256(irParam.pMin) * E12) {
            return uint216(irParam.rMax * E13);
        }
        if (USGPrice >= uint256(irParam.pMax) * E12) {
            return _returnMinIR(irParam.isHEC, irParam.rMin);
        }

        // x to pass in the σ(x) function, with x = k . (actualPrice - pInflexion)
        int128 sigmaX = -ABDKMath64x64.mul(ABDKMath64x64.fromUInt(irParam.k), ABDKMath64x64.divi(int256(USGPrice) - int256(int32(irParam.pInf)) * int256(E12), int256(ONE_ETHER)));
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
        int128 quotientFixedPoint = ABDKMath64x64.divu(((uint256(irParam.pMax) * E12) - USGPrice) / (irParam.pMax - irParam.pMin), E12);

        // To prevent tx to fail on log(0) in _pow in the computation of the IRIncrement
        // we return the minimum IR
        if (quotientFixedPoint == 0) {
            return _returnMinIR(irParam.isHEC, irParam.rMin);
        }

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

    function _pow(int128 a, int128 b) private pure returns (int128) {
        return ABDKMath64x64.exp_2(ABDKMath64x64.mul(ABDKMath64x64.log_2(a), b));
    }
}
