// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ITgUSD} from "../../interfaces/internals/tgUSD/ITgUSD.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";

import "forge-std/console.sol";

contract ControlTower is Ownable, IControlTower {
    address public feeTreasury;

    mapping(address => bool) public isZapper;

    mapping(address => bool) public isMarket;

    error NotIRProducer(address irProducer);

    constructor(address _owner, address _feeTreasury) Ownable(_owner) {
        feeTreasury = _feeTreasury;
    }

    error ContractNotMarket(address market);

    function getFeeTreasuryAndVerifyContractsAreMarkets(address[] calldata _markets) external view returns (address) {
        _isContractsMarkets(_markets);
        return feeTreasury;
    }

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

    function toggleZapper(address zapper) external onlyOwner {
        isZapper[zapper] = !isZapper[zapper];
    }
}
