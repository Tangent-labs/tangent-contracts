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

import {GlobalMarketInitParams, MarketInit, IRewardAccumulator, IERC20Metadata} from "../../interfaces/internals/USG/IMarketCore.sol";
import {IConvexCrvLPMarket, ICvxRewardToken} from "../../interfaces/internals/USG/IConvexCrvLPMarket.sol";
import {IConvexFxnLPMarket} from "../../interfaces/internals/USG/IConvexFxnLPMarket.sol";
import {IBasicERC20Market} from "../../interfaces/internals/USG/IBasicERC20Market.sol";
import {IControlTower} from "../../interfaces/internals/USG/IControlTower.sol";
import {IRParams, IIRCalculator} from "../../interfaces/internals/USG/IIRCalculator.sol";
import {RCParams} from "../../interfaces/internals/USG/IRewardAccumulator.sol";
import {IZappingProxy} from "../../interfaces/internals/USG/IZappingProxy.sol";
import {IUSG} from "../../interfaces/internals/USG/IUSG.sol";
/// @title MarketCreator
/// @notice Convergence's factory to deploy clone of contracts
contract MarketCreator is LightOwnable {
    using Clones for address;

    /// @notice Control tower
    IControlTower public controlTower;

    /// @notice USG token
    IUSG public USG;

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

    event MarketConvexCrvCreated(address proxy, string name);
    event MarketConvexFxnCreated(address proxy, string name);
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
        address _marketNoSociabilization
    ) {
        controlTower = _controlTower;
        USG = _USG;
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
                _USG: USG,
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
        IRParams calldata _irParams,
        RCParams calldata _rcParams
    ) external onlyOwner returns (address) {
        address proxy = marketConvexCrv.clone();
        IConvexCrvLPMarket(proxy).initialize(_getGlobalParams(), _marketInit, _cvxRewardToken, _pid);

        controlTower.toggleMarket(proxy);
        irCalculator.initializeMarket(proxy, _irParams);
        rewardAccumulator.initializeMarket(proxy, _rcParams);

        emit MarketConvexCrvCreated(proxy, _marketInit.name);
        return proxy;
    }

    function createConvexFxnMarket(MarketInit memory _marketInit, uint256 _pid, IRParams calldata _irParams, RCParams calldata _rcParams) external onlyOwner returns (address) {
        address proxy = marketConvexFxn.clone();
        IConvexFxnLPMarket(proxy).initialize(_getGlobalParams(), _marketInit, _pid);

        controlTower.toggleMarket(proxy);
        irCalculator.initializeMarket(proxy, _irParams);
        rewardAccumulator.initializeMarket(proxy, _rcParams);

        emit MarketConvexFxnCreated(proxy, _marketInit.name);
        return proxy;
    }

    function createBasicERC20Market(MarketInit memory _marketInit, IRParams calldata _irParams, RCParams calldata _rcParams) external onlyOwner returns (address) {
        address proxy = marketNoSociabilization.clone();
        IBasicERC20Market(proxy).initialize(_getGlobalParams(), _marketInit);

        controlTower.toggleMarket(proxy);
        irCalculator.initializeMarket(proxy, _irParams);
        rewardAccumulator.initializeMarket(proxy, _rcParams);

        emit BasicERC20MarketCreated(proxy, _marketInit.name);
        return proxy;
    }
}
