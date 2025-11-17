// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {LightOwnable} from "../Utilities/abstract/LightOwnable.sol";
import {IUSG} from "../../interfaces/internals/USG/IUSG.sol";
import {IControlTower} from "../../interfaces/internals/USG/IControlTower.sol";

/// @title ControlTower
/// @notice Owns the access control of the protocol.
contract ControlTower is LightOwnable, IControlTower {
    address public feeTreasury;

    mapping(address => bool) public isMarket;

    mapping(address => bool) public isMarketCreator;

    mapping(address => bool) public isIRCalculator;

    mapping(address => bool) public isPegKeeper;

    mapping(address => bool) public isPositionMigrator;

    mapping(address => bool) public isPauser;

    error NotIRProducer(address irProducer);

    error CallerNotOwnerOrMarketCreator(address caller);

    constructor(address _owner, address _feeTreasury) {
        feeTreasury = _feeTreasury;
        _transferOwnership(_owner);
    }

    /**
     *  @notice Returns true if all markets passed in param are really market. Else returns false.
     *  @param _markets  Market addresses to check.
     *  @return True if all markets really markets.
     */
    function areContractsMarkets(address[] calldata _markets) external view returns (bool) {
        uint256 len = _markets.length;
        for (uint256 i; i < len; ) {
            if (!isMarket[_markets[i]]) {
                return false;
            }
            unchecked {
                ++i;
            }
        }
        return true;
    }

    /**
     *  @notice Fetch the feeTreasury and verify if the address passed in parameter is an IRCalculator.
     *  @param  irCalculator Address to verify if it's really an IRCalculator
     *  @return The Fee Treasury address and a bool verifying the irCalculator.
     */
    function getFeeTreasuryAndIsIRCalculator(address irCalculator) external view returns (address, bool) {
        return (feeTreasury, isIRCalculator[irCalculator]);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        OWNER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    event SetFeeTreasury(address feeTreasury);
    event ToggleMarket(address market);
    event ToggleMarketCreator(address marketCreator);
    event TogglePegKeeper(address pegKeeper);
    event ToggleIRCalculator(address irCalculator);
    event TogglePositionMigrator(address migrator);
    event TogglePauser(address pauser);

    /**
     *  @notice Sets the receiver of the protocol fees
     *  @dev    Callable only by the owner.
     *  @param  _feeTreasury  New feeTreasury to setup
     */
    function setFeeTreasury(address _feeTreasury) external onlyOwner {
        feeTreasury = _feeTreasury;
        emit SetFeeTreasury(_feeTreasury);
    }

    /**
     *  @notice Toggle boolean linked to an address to flag it as market or no.
     *  @dev    Callable only by the owner or a MarketCreator.
     *  @param _market  Address to toggle.
     */
    function toggleMarket(address _market) external {
        require(owner == msg.sender || isMarketCreator[msg.sender], CallerNotOwnerOrMarketCreator(msg.sender));
        isMarket[_market] = !isMarket[_market];
        emit ToggleMarket(_market);
    }

    /**
     *  @notice Toggle boolean linked to an address to flag it as a MarketCreator.
     *  @dev    Callable only by the owner.
     *  @param  marketCreator  MarketCreator to toggle
     */
    function toggleMarketCreator(address marketCreator) external onlyOwner {
        isMarketCreator[marketCreator] = !isMarketCreator[marketCreator];
        emit ToggleMarketCreator(marketCreator);
    }

    /**
     *  @notice Toggle boolean linked to an address to flag it as a PegKeeper.
     *  @dev    Callable only by the owner.
     *  @param  pegKeeper  PegKeeper to toggle
     */
    function togglePegKeeper(address pegKeeper) external onlyOwner {
        isPegKeeper[pegKeeper] = !isPegKeeper[pegKeeper];
        emit TogglePegKeeper(pegKeeper);
    }

    /**
     *  @notice Toggle boolean linked to an address to flag it as an IRCalculator.
     *  @dev    Callable only by the owner.
     *  @param  irCalculator  IRCalculator to toggle
     */
    function toggleIRCalculator(address irCalculator) external onlyOwner {
        isIRCalculator[irCalculator] = !isIRCalculator[irCalculator];
        emit ToggleIRCalculator(irCalculator);
    }

    /**
     *  @notice Toggle boolean linked to an address to flag it as a Migrator.
     *  @dev    Callable only by the owner.
     *  @param  positionMigrator Migrator to toggle
     */
    function togglePositionMigrator(address positionMigrator) external onlyOwner {
        isPositionMigrator[positionMigrator] = !isPositionMigrator[positionMigrator];
        emit TogglePositionMigrator(positionMigrator);
    }

    /**
     *  @notice Toggle boolean linked to an address to flag it as a Pauser.
     *  @dev    Callable only by the owner.
     *  @param  _pauser Pauser to toggle
     */
    function togglePauser(address _pauser) external onlyOwner {
        isPauser[_pauser] = !isPauser[_pauser];
        emit TogglePauser(_pauser);
    }
}
