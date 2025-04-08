// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ITgUSD} from "../../interfaces/internals/tgUSD/ITgUSD.sol";
import {IDebtIR} from "../../interfaces/internals/tgUSD/IDebtIR.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import {IBridgeChecker} from "../../interfaces/internals/tgUSD/IBridgeChecker.sol";
import "forge-std/console.sol";
/// @notice
contract TgUSD is Ownable, ERC20, ITgUSD {
    IControlTower public controlTower;

    uint256 public mintableInterests;

    error CallerNotMinterBurner();
    error OnlyOwnerCanBridgeIfPermisionlessNotActive();
    error BridgingNotAllowed();

    constructor(string memory _name, string memory _symbol, address _owner, IControlTower _controlTower) ERC20(_name, _symbol) Ownable(_owner) {
        controlTower = _controlTower;
    }

    modifier onlyMarketCaller() {
        require(controlTower.isMarket(msg.sender), CallerNotMinterBurner());
        _;
    }

    function mint(address to, uint256 amount) external onlyMarketCaller {
        _mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) external onlyMarketCaller {
        _burn(from, amount);
    }

    function increaseMintableInterests(uint256 interests) external onlyMarketCaller {
        mintableInterests += interests;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function mintIR() external {
        _mint(controlTower.feeTreasury(), mintableInterests);
        delete mintableInterests;
    }
}
