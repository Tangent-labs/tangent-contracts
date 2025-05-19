// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ITgUSD} from "../../interfaces/internals/tgUSD/ITgUSD.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";

import "forge-std/console.sol";

contract ControlTower is Ownable, IControlTower {
    address public feeTreasury;

    mapping(address => bool) public isMarket;

    mapping(address => bool) public isMarketCreator;

    mapping(address => bool) public isIRCalculator;

    mapping(address => bool) public isPegKeeper;

    error NotIRProducer(address irProducer);

    error CallerNotOwnerOrMarketCreator(address caller);

    constructor(address _owner, address _feeTreasury) Ownable(_owner) {
        feeTreasury = _feeTreasury;
    }

    error ContractNotMarket(address market);

    function isContractsMarkets(address[] calldata _markets) external view {
        _isContractsMarkets(_markets);
    }

    function _isContractsMarkets(address[] calldata _markets) internal view {
        for (uint256 i; i < _markets.length; ) {
            require(isMarket[_markets[i]], ContractNotMarket(_markets[i]));
            unchecked {
                ++i;
            }
        }
    }

    /**
     *  @notice Toggle booleans linked to a list of address to flag them as market or no.
     *  @dev    Callable only by the owner.
     *  @param _markets  List of address to toggle.
     */
    function toggleMarkets(address[] calldata _markets) external onlyOwner {
        for (uint256 i; i < _markets.length; ) {
            address _market = _markets[i];
            // Toggle the address
            isMarket[_market] = !isMarket[_market];
            unchecked {
                ++i;
            }
        }
    }

    /**
     *  @notice Toggle boolean linked to an address to flag it as market or no.
     *  @dev    Callable only by the owner or a MarketCreator.
     *  @param _market  Address to toggle.
     */
    function toggleMarket(address _market) external {
        require(owner() == msg.sender || isMarketCreator[msg.sender], CallerNotOwnerOrMarketCreator(msg.sender));
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
