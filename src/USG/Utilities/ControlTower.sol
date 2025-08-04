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

    error NotIRProducer(address irProducer);

    error CallerNotOwnerOrMarketCreator(address caller);

    constructor(address _owner, address _feeTreasury) {
        feeTreasury = _feeTreasury;
        _transferOwnership(_owner);
    }

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

    function getFeeTreasuryAndIsIRCalculator(address irCalculator) external view returns (address, bool) {
        return (feeTreasury, isIRCalculator[irCalculator]);
    }

    function setFeeTreasury(address _feeTreasury) external onlyOwner {
        feeTreasury = _feeTreasury;
    }

    /**
     *  @notice Toggle boolean linked to an address to flag it as market or no.
     *  @dev    Callable only by the owner or a MarketCreator.
     *  @param _market  Address to toggle.
     */
    function toggleMarket(address _market) external {
        require(owner == msg.sender || isMarketCreator[msg.sender], CallerNotOwnerOrMarketCreator(msg.sender));
        isMarket[_market] = !isMarket[_market];
    }

    function toggleMarketCreator(address marketCreator) external onlyOwner {
        isMarketCreator[marketCreator] = !isMarketCreator[marketCreator];
    }

    function togglePegKeeper(address pegKeeper) external onlyOwner {
        isPegKeeper[pegKeeper] = !isPegKeeper[pegKeeper];
    }

    function toggleIRCalculator(address irCalculator) external onlyOwner {
        isIRCalculator[irCalculator] = !isIRCalculator[irCalculator];
    }
}
