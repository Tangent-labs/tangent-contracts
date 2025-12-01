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

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {LightOwnable} from "../../src/USG/Utilities/abstract/LightOwnable.sol";

import {GlobalMarketInitParams, MarketInit, IRewardAccumulator, IERC20Metadata, IERC20} from "../../src/interfaces/internals/USG/IMarketCore.sol";
import {IConvexCrvLPMarket, ICvxRewardToken} from "../../src/interfaces/internals/USG/IConvexCrvLPMarket.sol";
import {IBasicERC20Market} from "../../src/interfaces/internals/USG/IBasicERC20Market.sol";
import {IControlTower} from "../../src/interfaces/internals/USG/IControlTower.sol";
import {IRParams, IIRCalculator} from "../../src/interfaces/internals/USG/IIRCalculator.sol";
import {RCParams} from "../../src/interfaces/internals/USG/IRewardAccumulator.sol";
import {IZappingProxy} from "../../src/interfaces/internals/USG/IZappingProxy.sol";
import {IUSG} from "../../src/interfaces/internals/USG/IUSG.sol";

import "forge-std/console.sol";
/// @title  MarketCreator2Mock
/// @notice Factory to deploy market following the Minimal proxy implementation
contract MarketCreator2Mock is LightOwnable {
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

    event MarketConvexCrvCreated(address proxy, string name);

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
        address _marketConvexCrv
    ) {
        controlTower = _controlTower;
        USG = _USG;
        irCalculator = _irCalculator;
        rewardAccumulator = _rewardAccumulator;
        zappingProxy = _zappingProxy;
        marketConvexCrv = _marketConvexCrv;
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

    function _commonInitialize(address newProxy, IRParams calldata _irParams, IERC20[] calldata rewardTokens, RCParams calldata _rcParams) internal {
        USG.initializeMarket(newProxy);
        irCalculator.initializeMarket(newProxy, _irParams);
        rewardAccumulator.initializeMarket(newProxy, rewardTokens, _rcParams);
    }
}
