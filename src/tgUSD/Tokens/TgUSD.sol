// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ITgUSD} from "../../interfaces/internals/tgUSD/ITgUSD.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import {LightOwnable} from "../../tgUSD/Utilities/abstract/LightOwnable.sol";

import "forge-std/console.sol";
/// @notice
contract TgUSD is ERC20, ITgUSD, LightOwnable {
    IControlTower public controlTower;

    error OnlyMarketCaller();
    error OnlyIRCalculator();
    error MintOnlyOnPegKeeper();

    constructor(address _owner, string memory _name, string memory _symbol, IControlTower _controlTower) ERC20(_name, _symbol) {
        owner = _owner;
        controlTower = _controlTower;
    }

    modifier onlyMarketCaller() {
        require(controlTower.isMarket(msg.sender), OnlyMarketCaller());
        _;
    }

    function mint(address to, uint256 amount) external onlyMarketCaller {
        _mint(to, amount);
    }

    function mintIR(uint256 amount) external {
        IControlTower _controlTower = controlTower;
        require(_controlTower.isIRCalculator(msg.sender), OnlyIRCalculator());
        _mint(_controlTower.feeTreasury(), amount);
    }

    function mintPegKeeper(uint256 amount, address pegKeeper) external onlyOwner {
        require(controlTower.isPegKeeper(pegKeeper), MintOnlyOnPegKeeper());
        _mint(pegKeeper, amount);
    }

    function burnFrom(address from, uint256 amount) external onlyMarketCaller {
        _burn(from, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
