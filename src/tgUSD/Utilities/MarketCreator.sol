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

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

import {IMarketCore, IRewardAccumulator, IERC20Metadata} from "../../interfaces/internals/tgUSD/IMarketCore.sol";
import {IConvexCrvLPMarket, ICvxRewardToken} from "../../interfaces/internals/tgUSD/IConvexCrvLPMarket.sol";
import {IConvexFxnLPMarket} from "../../interfaces/internals/tgUSD/IConvexFxnLPMarket.sol";
import {IMarketNoSociabilization} from "../../interfaces/internals/tgUSD/IMarketNoSociabilization.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import {IIRCalculator} from "../../interfaces/internals/tgUSD/IIRCalculator.sol";
import {ITgUSD} from "../../interfaces/internals/tgUSD/ITgUSD.sol";

/// @title Cvg-Finance - CloneFactoryV2
/// @notice Convergence's factory to deploy clone of contracts
contract MarketCreator is Ownable {
    using Clones for address;

    /// @notice
    IControlTower public controlTower;

    /// @notice
    ITgUSD public tgUSD;

    /// @notice
    IIRCalculator public irCalculator;

    /// @notice
    IRewardAccumulator public rewardAccumulator;

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
        address _marketConvexCrv,
        address _marketConvexFxn,
        address _marketNoSociabilization
    ) Ownable(_owner) {
        controlTower = _controlTower;
        tgUSD = _tgUSD;
        irCalculator = _irCalculator;
        rewardAccumulator = _rewardAccumulator;
        marketConvexCrv = _marketConvexCrv;
        marketConvexFxn = _marketConvexFxn;
        marketNoSociabilization = _marketNoSociabilization;
    }

    function createConvexCrvMarket(
        IMarketCore.MarketInit memory _marketInit,
        ICvxRewardToken _cvxRewardToken,
        uint256 _pid,
        uint256 _socFeePercentage,
        IIRCalculator.IRParams calldata _irParams,
        IIRCalculator.RCParams calldata _rcParams
    ) external onlyOwner returns (address) {
        address proxy = marketConvexCrv.clone();
        IConvexCrvLPMarket(proxy).initialize(
            IMarketCore.MarketConstants({_owner: owner(), _tgUSD: tgUSD, _controlTower: controlTower, _irCalculator: irCalculator, _rewardAccumulator: rewardAccumulator}),
            _marketInit,
            _cvxRewardToken,
            _pid,
            _socFeePercentage
        );

        controlTower.toggleMarket(proxy);
        irCalculator.setUpMarketRewards(proxy, _irParams, _rcParams);

        emit MarketConvexCrvCreated(proxy);
        return proxy;
    }

    function createConvexFxnMarket(
        IMarketCore.MarketInit memory _marketInit,
        uint256 _pid,
        uint256 _socFeePercentage,
        IIRCalculator.IRParams calldata _irParams,
        IIRCalculator.RCParams calldata _rcParams
    ) external onlyOwner returns (address) {
        address proxy = marketConvexFxn.clone();
        IConvexFxnLPMarket(proxy).initialize(
            IMarketCore.MarketConstants({_owner: owner(), _tgUSD: tgUSD, _controlTower: controlTower, _irCalculator: irCalculator, _rewardAccumulator: rewardAccumulator}),
            _marketInit,
            _pid,
            _socFeePercentage
        );

        controlTower.toggleMarket(proxy);
        irCalculator.setUpMarketRewards(proxy, _irParams, _rcParams);

        emit MarketConvexFxnCreated(proxy);
        return proxy;
    }

    function createNoSociabilizationMarket(
        IMarketCore.MarketInit memory _marketInit,
        IIRCalculator.IRParams calldata _irParams,
        IIRCalculator.RCParams calldata _rcParams
    ) external onlyOwner returns (address) {
        address proxy = marketNoSociabilization.clone();
        IMarketNoSociabilization(proxy).initialize(
            IMarketCore.MarketConstants({_owner: owner(), _tgUSD: tgUSD, _controlTower: controlTower, _irCalculator: irCalculator, _rewardAccumulator: rewardAccumulator}),
            _marketInit
        );

        controlTower.toggleMarket(proxy);
        irCalculator.setUpMarketRewards(proxy, _irParams, _rcParams);

        emit MarketNoSociabilizationCreated(proxy);
        return proxy;
    }
}
