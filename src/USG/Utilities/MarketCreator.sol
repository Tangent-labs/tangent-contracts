// SPDX-License-Identifier: MIT
/**
 _____
/  __ \
| /  \/ ___  _ ____   _____ _ __ __ _  ___ _ __   ___ ___
| |    / _ \| '_ \ \ / / _ \ '__/ _` |/ _ \ '_ \ / __/ _ \
| \__/\ (_) | | | \ V /  __/ | | (_| |  __/ | | | (_|  __/
 \____/\___/|_| |_|\_/ \___|_|  \__, |\___|_| |_|\___\___|
                                 __/ |
                                |___/
 */
pragma solidity ^0.8.0;

import {LightOwnable} from "../Utilities/abstract/LightOwnable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {GlobalMarketInitParams, MarketInit, IRewardAccumulator, IERC20Metadata, IERC20} from "../../interfaces/internals/USG/IMarketCore.sol";
import {IConvexCrvLPMarket, ICvxRewardToken} from "../../interfaces/internals/USG/IConvexCrvLPMarket.sol";
import {ICurveGaugeMarket, IGauge} from "../../interfaces/internals/USG/ICurveGaugeMarket.sol";
import {IStakeDaoVaultV2Market, IStakeDaoVaultV2} from "../../interfaces/internals/USG/IStakeDaoVaultV2Market.sol";
import {IConvexFxnLPMarket} from "../../interfaces/internals/USG/IConvexFxnLPMarket.sol";
import {IBasicERC20Market} from "../../interfaces/internals/USG/IBasicERC20Market.sol";
import {IControlTower} from "../../interfaces/internals/USG/IControlTower.sol";
import {IRParams, IIRCalculator} from "../../interfaces/internals/USG/IIRCalculator.sol";
import {RCParams} from "../../interfaces/internals/USG/IRewardAccumulator.sol";
import {IZappingProxy} from "../../interfaces/internals/USG/IZappingProxy.sol";
import {IUSG} from "../../interfaces/internals/USG/IUSG.sol";

/// @title  MarketCreator
/// @author Tangent Finance
/// @notice Factory to deploy market following the Minimal proxy implementation
contract MarketCreator is LightOwnable {
    using Clones for address;

    /// @notice Control tower
    IControlTower public controlTower;

    /// @notice USG token
    IUSG public USG;

    /// @notice IR Calculator
    IIRCalculator public irCalculator;

    /// @notice Reward accumulator
    IRewardAccumulator public rewardAccumulator;

    /// @notice Zapping proxy
    IZappingProxy public zappingProxy;

    /// @notice Convex CRV market implementation
    address public marketConvexCrv;

    /// @notice Convex FXN market implementation
    address public marketConvexFxn;

    /// @notice Market Curve gauge implementation
    address public marketCurveGauge;

    /// @notice Market Curve gauge implementation
    address public marketStakeDaoVaultV2;

    /// @notice Basic ERC20 market implementation
    address public marketBasicERC20;

    event MarketConvexCrvCreated(address proxy, string name);
    event MarketConvexFxnCreated(address proxy, string name);
    event MarketCurveGaugeCreated(address proxy, string name);
    event MarketStakeDaoVaultV2Created(address proxy, string name);
    event BasicERC20MarketCreated(address proxy, string name);

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            CONSTRUCTOR
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    constructor(
        address _owner,
        IControlTower _controlTower,
        IUSG _USG,
        IIRCalculator _irCalculator,
        IRewardAccumulator _rewardAccumulator,
        IZappingProxy _zappingProxy,
        address _marketConvexCrv,
        address _marketConvexFxn,
        address _marketCurveGauge,
        address _marketStakeDaoVaultV2,
        address _marketBasicERC20
    ) {
        controlTower = _controlTower;
        USG = _USG;
        irCalculator = _irCalculator;
        rewardAccumulator = _rewardAccumulator;
        zappingProxy = _zappingProxy;
        marketConvexCrv = _marketConvexCrv;
        marketConvexFxn = _marketConvexFxn;
        marketCurveGauge = _marketCurveGauge;
        marketStakeDaoVaultV2 = _marketStakeDaoVaultV2;
        marketBasicERC20 = _marketBasicERC20;
        _transferOwnership(_owner);
    }

    function _getGlobalParams() internal view returns (GlobalMarketInitParams memory) {
        return
            GlobalMarketInitParams({
                _owner: owner,
                _USG: USG,
                _controlTower: controlTower,
                _irCalculator: irCalculator,
                _rewardAccumulator: rewardAccumulator,
                _zappingProxy: zappingProxy
            });
    }

    /**
     *  @notice Creates a market with a Curve Convex LP as Collateral.
     *  @dev    Only on callable by DAO
     *  @param _marketInit     Market init parameter containing all data related to the market
     *  @param _pid            Pool ID of Curve Convex LP
     *  @param _irParams       Interest Rate parameters of the market
     *  @param _rcParams       Reward Cut parameters of the market
     */
    function createConvexCrvMarket(MarketInit calldata _marketInit, uint256 _pid, IRParams calldata _irParams, RCParams calldata _rcParams) external onlyOwner returns (address) {
        address proxy = marketConvexCrv.clone();
        IConvexCrvLPMarket(proxy).initialize(_getGlobalParams(), _marketInit, _pid);
        _commonInitialize(proxy, _irParams, _marketInit.rewardTokens, _rcParams);
        emit MarketConvexCrvCreated(proxy, _marketInit.name);
        return proxy;
    }

    /**
     *  @notice Creates a market with a FXN Convex LP as Collateral.
     *  @dev    Only on callable by DAO
     *  @param _marketInit     Market init parameter containing all data related to the market
     *  @param _pid            Pool ID of FXN Convex LP
     *  @param _irParams       Interest Rate parameters of the market
     *  @param _rcParams       Reward Cut parameters of the market
     */
    function createConvexFxnMarket(MarketInit calldata _marketInit, uint256 _pid, IRParams calldata _irParams, RCParams calldata _rcParams) external onlyOwner returns (address) {
        address proxy = marketConvexFxn.clone();
        IConvexFxnLPMarket(proxy).initialize(_getGlobalParams(), _marketInit, _pid);
        _commonInitialize(proxy, _irParams, _marketInit.rewardTokens, _rcParams);
        emit MarketConvexFxnCreated(proxy, _marketInit.name);
        return proxy;
    }

    /**
     *  @notice Creates a market with a Curve Convex LP as Collateral.
     *  @dev    Only on callable by DAO
     *  @param _marketInit     Market init parameter containing all data related to the market
     *  @param _irParams       Interest Rate parameters of the market
     *  @param _rcParams       Reward Cut parameters of the market
     */
    function createCurveGaugeMarket(MarketInit calldata _marketInit, IGauge _gauge, IRParams calldata _irParams, RCParams calldata _rcParams) external onlyOwner returns (address) {
        address proxy = marketCurveGauge.clone();
        ICurveGaugeMarket(proxy).initialize(_getGlobalParams(), _marketInit, _gauge);
        _commonInitialize(proxy, _irParams, _marketInit.rewardTokens, _rcParams);
        emit MarketCurveGaugeCreated(proxy, _marketInit.name);
        return proxy;
    }

    /**
     *  @notice Creates a market with a Curve Convex LP as Collateral.
     *  @dev    Only on callable by DAO
     *  @param _marketInit     Market init parameter containing all data related to the market
     *  @param _irParams       Interest Rate parameters of the market
     *  @param _rcParams       Reward Cut parameters of the market
     */
    function createStakeDaoVaultV2Market(
        MarketInit calldata _marketInit,
        IStakeDaoVaultV2 _vault,
        IRParams calldata _irParams,
        RCParams calldata _rcParams
    ) external onlyOwner returns (address) {
        address proxy = marketStakeDaoVaultV2.clone();
        IStakeDaoVaultV2Market(proxy).initialize(_getGlobalParams(), _marketInit, _vault);
        _commonInitialize(proxy, _irParams, _marketInit.rewardTokens, _rcParams);
        emit MarketStakeDaoVaultV2Created(proxy, _marketInit.name);
        return proxy;
    }

    /**
     *  @notice Creates a market with a basic ERC20 as collateral, without reward streaming coming from the collateral.
     *  @dev    Only on callable by DAO
     *  @param _marketInit     Market init parameter containing all data related to the market
     *  @param _irParams       Interest Rate parameters of the market
     *  @param _rcParams       Reward Cut parameters of the market
     */
    function createBasicERC20Market(MarketInit calldata _marketInit, IRParams calldata _irParams, RCParams calldata _rcParams) external onlyOwner returns (address) {
        address proxy = marketBasicERC20.clone();
        IBasicERC20Market(proxy).initialize(_getGlobalParams(), _marketInit);
        _commonInitialize(proxy, _irParams, _marketInit.rewardTokens, _rcParams);
        emit BasicERC20MarketCreated(proxy, _marketInit.name);
        return proxy;
    }

    function _commonInitialize(address newProxy, IRParams calldata _irParams, IERC20[] calldata rewardTokens, RCParams calldata _rcParams) internal {
        // Set market as minter and burner of USG
        USG.initializeMarket(newProxy);
        // Set up IRParams and initialize debt index for the market
        irCalculator.initializeMarket(newProxy, _irParams);
        // Set up RewardCut params and initialize debt index for the market
        rewardAccumulator.initializeMarket(newProxy, rewardTokens, _rcParams);
    }
}
