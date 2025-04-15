// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ITgUSD} from "../../interfaces/internals/tgUSD/ITgUSD.sol";
import {IDebtIR} from "../../interfaces/internals/tgUSD/IDebtIR.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";

import {IBridgeChecker} from "../../interfaces/internals/tgUSD/IBridgeChecker.sol";
import "forge-std/console.sol";
/// @notice
contract TgUSD is ERC20, Ownable, ITgUSD {
    IControlTower public controlTower;

    address public irCalculator;

    error OnlyMarketCaller();
    error OnlyIRCalculator();

    constructor(string memory _name, string memory _symbol, address _owner, IControlTower _controlTower, address _irCalculator) ERC20(_name, _symbol) Ownable(_owner) {
        controlTower = _controlTower;
        irCalculator = _irCalculator;
    }

    modifier onlyMarketCaller() {
        require(controlTower.isMarket(msg.sender), OnlyMarketCaller());
        _;
    }

    function mint(address to, uint256 amount) external onlyMarketCaller {
        _mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) external onlyMarketCaller {
        _burn(from, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function mintIR(uint256 amount) external {
        require(msg.sender == irCalculator, OnlyIRCalculator());
        _mint(controlTower.feeTreasury(), amount);
    }
}
