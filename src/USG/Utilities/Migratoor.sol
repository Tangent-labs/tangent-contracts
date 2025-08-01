// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {LightReentrancyGuardTransient} from "../Utilities/abstract/LightReentrancyGuardTransient.sol";

import {IMarketExternalActions} from "../../interfaces/internals/USG/IMarketExternalActions.sol";
import {ICollateral} from "../../interfaces/internals/USG/ICollateral.sol";

import {MigrateStruct, ZapMigrateStruct} from "../../interfaces/internals/USG/IMigratoor.sol";
import {IUSG} from "../../interfaces/internals/USG/IUSG.sol";
import {IControlTower} from "../../interfaces/internals/USG/IControlTower.sol";
import {IZappingProxy} from "../../interfaces/internals/USG/IZappingProxy.sol";

import {ZapStruct} from "../../interfaces/internals/ICommonStruct.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title  Migratoor
/// @notice This contract is used fully or partially migrate a position to an other market.
///         It prevent user to repay, withdraw, swap his collateral by himself etc.
contract Migratoor is LightReentrancyGuardTransient {
    IUSG public usg;
    IControlTower public controlTower;
    IZappingProxy public zappingProxy;

    error NotAMarket();
    error IdenticalMarkets();
    constructor(IControlTower _controlTower, IUSG _usg, IZappingProxy _zappingProxy) {
        controlTower = _controlTower;
        usg = _usg;
        zappingProxy = _zappingProxy;
    }

    /**
     * @notice Migrate fully or partially one position from a `marketFrom` to a `marketTo`.
     *
     * @dev
     * @param  migrationData  Struct containing data to perform the migration :
     *                          - markets[] : 2 dimensional array with market[0] being the marketFrom and market[1] the marketTo.
     *                          - collatToWithdraw : Amount of collateral to remove from the marketFrom
     *                          - debtToRemove : Amount of debt to remove from the marketFrom
     *                          - debtToRepay : Amount of USG to repay from the debtToRemove.
     * @param  zapCollatData  Struct containing data to perform the zap of the collatFrom to collatTo :
     *                          - zap : Struct containing the router and the raw data
     *                          - minCollatToOut : Minimum amount of collatTo received by the marketTo
     */
    function migrate(MigrateStruct calldata migrationData, ZapMigrateStruct calldata zapCollatData) external nonReentrant {
        IMarketExternalActions marketFrom = IMarketExternalActions(migrationData.markets[0]);
        IMarketExternalActions marketTo = IMarketExternalActions(migrationData.markets[1]);
        IControlTower _controlTower = controlTower;

        // Verify that both contracts are vevrified markets in the ControlTower
        require(_controlTower.areContractsMarkets(migrationData.markets), NotAMarket());
        // Verify that both markets are different
        require(marketFrom != marketTo, IdenticalMarkets());

        IERC20 collatFrom = ICollateral(address(marketFrom)).collatToken();
        // Block all calls to the market TO to prevent exploit in the raw call in ZappingProxy
        IERC20 collatTo = marketTo.reeantrancyOn(_controlTower);

        bool isSameCollat = collatFrom == collatTo;
        IZappingProxy _zappingProxy = zappingProxy;

        uint256 transferedDebt = marketFrom.migrateFrom(
            _controlTower,
            msg.sender,
            migrationData.collatToWithdraw,
            migrationData.debtToRemove,
            migrationData.debtToRepay,
            isSameCollat ? address(marketTo) : address(_zappingProxy)
        );

        uint256 collatReceived = migrationData.collatToWithdraw;

        if (!isSameCollat) {
            collatReceived = _zappingProxy.zapProxy(collatFrom, collatTo, zapCollatData.minCollatToOut, address(marketTo), zapCollatData.zap);
        }

        marketTo.reeantrancyOff(_controlTower);

        marketTo.migrateTo(_controlTower, msg.sender, collatReceived, transferedDebt);
    }
}
