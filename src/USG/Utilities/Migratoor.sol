// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {LightReentrancyGuardTransient} from "../Utilities/abstract/LightReentrancyGuardTransient.sol";

import {IMarketExternalActions} from "../../interfaces/internals/USG/IMarketExternalActions.sol";
import {ICollateral} from "../../interfaces/internals/USG/ICollateral.sol";
import {LightOwnable} from "../Utilities/abstract/LightOwnable.sol";

import {MigrateStruct, ZapMigrateStruct} from "../../interfaces/internals/USG/IMigratoor.sol";
import {IControlTower} from "../../interfaces/internals/USG/IControlTower.sol";
import {IZappingProxy} from "../../interfaces/internals/USG/IZappingProxy.sol";

import {ZapStruct} from "../../interfaces/internals/ICommonStruct.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title  Migratoor
/// @author Tangent Finance
/// @notice This contract can be used to fully or partially migrate a position to an other market.
///         It prevent user to repay, withdraw, swap his collateral by himself etc.
contract Migratoor is LightOwnable, LightReentrancyGuardTransient {
    IZappingProxy public zappingProxy;

    mapping(address => bool) public isMarket;

    error NotAMarket();
    error IdenticalMarkets();
    error CallerNotOwner();

    event SetIsMarket(address market, bool _isMarket);
    constructor(address owner, IZappingProxy _zappingProxy) {
        zappingProxy = _zappingProxy;
        _transferOwnership(owner);
    }

    /**
     * @notice Sets or removes the market flag for a given address
     * @dev    Restricted to the contract owner or addresses with the MarketCreator role.
     *         Emits a {SetIsMarket} event on success.
     * @param _market     The address to update the market status for
     *         Whether the address should be flagged as a market (true) or not (false)
     */
    function setIsMarket(address _market, bool _isMarket) external onlyOwner {
        isMarket[_market] = _isMarket;
        emit SetIsMarket(_market, _isMarket);
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
        IMarketExternalActions marketFrom = IMarketExternalActions(migrationData.marketFrom);
        IMarketExternalActions marketTo = IMarketExternalActions(migrationData.marketTo);

        // Verify that marketFrom is flagged as a Market
        require(isMarket[address(marketFrom)], NotAMarket());
        // Verify that marketTo is flagged as a Market
        require(isMarket[address(marketTo)], NotAMarket());
        // Verify that both markets are different
        require(marketFrom != marketTo, IdenticalMarkets());

        IERC20 collatFrom = ICollateral(address(marketFrom)).collatToken();
        // Block all calls to the market TO to prevent exploit in the raw call in ZappingProxy
        IERC20 collatTo = marketTo.reeantrancyOn();

        bool isSameCollat = collatFrom == collatTo;
        IZappingProxy _zappingProxy = zappingProxy;

        // Removes debt and collateral from source market.
        uint256 transferedDebt = marketFrom.migrateFrom(
            msg.sender,
            migrationData.collatToWithdraw,
            migrationData.debtToRemove,
            migrationData.debtToRepay,
            isSameCollat ? address(marketTo) : address(_zappingProxy)
        );

        uint256 collatReceived = migrationData.collatToWithdraw;

        // Only needed if collatFrom is different from collatTo
        if (!isSameCollat) {
            // Performs the zap from collatFrom to collatTo.
            // CollatTo receiver is marketTo
            collatReceived = _zappingProxy.zapProxy(collatFrom, collatTo, zapCollatData.minCollatToOut, address(marketTo), zapCollatData.zap);
        }

        // Shut down the reeantrancy guard on marketTo
        marketTo.reeantrancyOff();

        // Add collateral balances and debt to marketTo
        marketTo.migrateTo(msg.sender, collatReceived, transferedDebt);
    }
}
