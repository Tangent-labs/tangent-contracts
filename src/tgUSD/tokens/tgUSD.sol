// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {ItgUSD} from "../../interfaces/internals/tgUSD/ItgUSD.sol";
import {IDebtIR} from "../../interfaces/internals/tgUSD/IDebtIR.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";

import "forge-std/console.sol";
/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract TgUSD is OFT, ItgUSD {
    IControlTower public controlTower;

    uint256 public mintableInterests;

    error CallerNotMinterBurner();

    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate,
        address _owner,
        IControlTower _controlTower
    ) OFT(_name, _symbol, _lzEndpoint, _delegate) Ownable(_owner) {
        controlTower = _controlTower;
    }

    modifier onlyMarketCaller() {
        require(controlTower.isMarket(msg.sender), CallerNotMinterBurner());
        _;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function mintIR() external {
        _mint(controlTower.feeTreasury(), mintableInterests);
        delete mintableInterests;
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
}
