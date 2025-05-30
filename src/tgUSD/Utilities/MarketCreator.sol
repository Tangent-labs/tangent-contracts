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

import {GlobalMarketInitParams, MarketInit, IRewardAccumulator, IERC20Metadata} from "../../interfaces/internals/tgUSD/IMarketCore.sol";
import {IConvexCrvLPMarket, ICvxRewardToken} from "../../interfaces/internals/tgUSD/IConvexCrvLPMarket.sol";
import {IConvexFxnLPMarket} from "../../interfaces/internals/tgUSD/IConvexFxnLPMarket.sol";
import {IMarketNoSociabilization} from "../../interfaces/internals/tgUSD/IMarketNoSociabilization.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import {IRParams, IIRCalculator} from "../../interfaces/internals/tgUSD/IIRCalculator.sol";
import {RCParams} from "../../interfaces/internals/tgUSD/IRewardAccumulator.sol";
import {IZappingProxy} from "../../interfaces/internals/tgUSD/IZappingProxy.sol";
import {ITgUSD} from "../../interfaces/internals/tgUSD/ITgUSD.sol";
/// @title MarketCreator
/// @notice Convergence's factory to deploy clone of contracts
contract MarketCreator is LightOwnable {
    using Clones for address;

    /// @notice Control tower
    IControlTower public controlTower;

    /// @notice TgUSD token
    ITgUSD public tgUSD;

    /// @notice IR Calculator
    IIRCalculator public irCalculator;

    /// @notice
    IRewardAccumulator public rewardAccumulator;

    /// @notice
    IZappingProxy public zappingProxy;

    /// @notice
    address public marketConvexCrv;

    /// @notice
    address public marketConvexFxn;

    /// @notice
    address public marketNoSociabilization;

    event MarketConvexCrvCreated(address proxy);
    event MarketConvexFxnCreated(address proxy);
    event MarketNoSociabilizationCreated(address proxy);

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                            CONSTRUCTOR
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    constructor(
        address _owner,
        IControlTower _controlTower,
        ITgUSD _tgUSD,
        IIRCalculator _irCalculator,
        IRewardAccumulator _rewardAccumulator,
        IZappingProxy _zappingProxy,
        address _marketConvexCrv,
        address _marketConvexFxn,
        address _marketNoSociabilization
    ) {
        controlTower = _controlTower;
        tgUSD = _tgUSD;
        irCalculator = _irCalculator;
        rewardAccumulator = _rewardAccumulator;
        zappingProxy = _zappingProxy;
        marketConvexCrv = _marketConvexCrv;
        marketConvexFxn = _marketConvexFxn;
        marketNoSociabilization = _marketNoSociabilization;
        _transferOwnership(_owner);
    }

    function _getGlobalParams() internal view returns (GlobalMarketInitParams memory) {
        return
            GlobalMarketInitParams({
                _owner: owner,
                _tgUSD: tgUSD,
                _controlTower: controlTower,
                _irCalculator: irCalculator,
                _rewardAccumulator: rewardAccumulator,
                _zappingProxy: zappingProxy
            });
    }

    function createConvexCrvMarket(
        MarketInit memory _marketInit,
        ICvxRewardToken _cvxRewardToken,
        uint256 _pid,
        uint256 _socFeePercentage,
        IRParams calldata _irParams,
        RCParams calldata _rcParams
    ) external onlyOwner returns (address) {
        address proxy = marketConvexCrv.clone();
        IConvexCrvLPMarket(proxy).initialize(_getGlobalParams(), _marketInit, _cvxRewardToken, _pid, _socFeePercentage);

        controlTower.toggleMarket(proxy);
        irCalculator.initializeMarket(proxy, _irParams);
        rewardAccumulator.initializeMarket(proxy, _rcParams);

        emit MarketConvexCrvCreated(proxy);
        return proxy;
    }

    function createConvexFxnMarket(
        MarketInit memory _marketInit,
        uint256 _pid,
        uint256 _socFeePercentage,
        IRParams calldata _irParams,
        RCParams calldata _rcParams
    ) external onlyOwner returns (address) {
        address proxy = marketConvexFxn.clone();
        IConvexFxnLPMarket(proxy).initialize(_getGlobalParams(), _marketInit, _pid, _socFeePercentage);

        controlTower.toggleMarket(proxy);
        irCalculator.initializeMarket(proxy, _irParams);
        rewardAccumulator.initializeMarket(proxy, _rcParams);

        emit MarketConvexFxnCreated(proxy);
        return proxy;
    }

    function createNoSociabilizationMarket(MarketInit memory _marketInit, IRParams calldata _irParams, RCParams calldata _rcParams) external onlyOwner returns (address) {
        address proxy = marketNoSociabilization.clone();
        IMarketNoSociabilization(proxy).initialize(_getGlobalParams(), _marketInit);

        controlTower.toggleMarket(proxy);
        irCalculator.initializeMarket(proxy, _irParams);
        rewardAccumulator.initializeMarket(proxy, _rcParams);

        emit MarketNoSociabilizationCreated(proxy);
        return proxy;
    }
}
