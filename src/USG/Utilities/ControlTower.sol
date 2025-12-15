// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {LightOwnable} from "../Utilities/abstract/LightOwnable.sol";
import {IUSG} from "../../interfaces/internals/USG/IUSG.sol";
import {IControlTower} from "../../interfaces/internals/USG/IControlTower.sol";

/// @title ControlTower
/// @author Tangent Finance
/// @notice Owns the access control of the protocol.
contract ControlTower is LightOwnable, IControlTower {
    address public feeTreasury;

    mapping(address => bool) public isMarketCreator;

    mapping(address => bool) public isPositionMigrator;

    mapping(address => bool) public isPauser;

    error NotIRProducer(address irProducer);

    error CallerNotOwnerOrMarketCreator(address caller);

    constructor(address _owner, address _feeTreasury) {
        feeTreasury = _feeTreasury;
        _transferOwnership(_owner);
    }

    event SetFeeTreasury(address feeTreasury);
    event SetIsMarketCreator(address marketCreator, bool _isMarketCreator);
    event SetIsPositionMigrator(address migrator, bool _isPositionMigrator);
    event SetIsPauser(address pauser, bool _isPauser);

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        OWNER ACTIONS 
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

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
     * @notice Sets or removes the market creator flag for a given address
     * @dev    Restricted to the contract owner.
     * @param marketCreator     The address to update the market status for
     * @param _isMarketCreator  Whether the address should be flagged as a market creator (true) or not (false)
     */
    function setIsMarketCreator(address marketCreator, bool _isMarketCreator) external onlyOwner {
        isMarketCreator[marketCreator] = _isMarketCreator;
        emit SetIsMarketCreator(marketCreator, _isMarketCreator);
    }

    /**
     * @notice Sets or removes the position migrator flag for a given address
     * @dev    Restricted to the contract owner
     * @param positionMigrator     The address to update the position migrator status for
     * @param _isPositionMigrator  Whether the address should be flagged as a position migrator (true) or not (false)
     */
    function setIsPositionMigrator(address positionMigrator, bool _isPositionMigrator) external onlyOwner {
        isPositionMigrator[positionMigrator] = _isPositionMigrator;
        emit SetIsPositionMigrator(positionMigrator, _isPositionMigrator);
    }

    /**
     * @notice Sets or removes the pauser flag for a given address
     * @dev    Restricted to the contract owner.
     * @param _pauser     The address to update the pauser status for
     * @param _isPauser   Whether the address should be flagged as a pauser (true) or not (false)
     */
    function setIsPauser(address _pauser, bool _isPauser) external onlyOwner {
        isPauser[_pauser] = _isPauser;
        emit SetIsPauser(_pauser, _isPauser);
    }
}
