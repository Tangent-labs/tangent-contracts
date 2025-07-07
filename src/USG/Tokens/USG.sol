// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IUSG} from "../../interfaces/internals/USG/IUSG.sol";
import {IControlTower} from "../../interfaces/internals/USG/IControlTower.sol";
import {LightOwnable} from "../../USG/Utilities/abstract/LightOwnable.sol";

/// @notice
contract USG is ERC20, IUSG, LightOwnable {
    IControlTower public controlTower;

    error OnlyMarketCaller();
    error OnlyIRCalculator();
    error MintOnlyOnPegKeeper();

    /**
     * @notice Constructor of USG
     * @param _dao           Address of the DAO that becomes the owner of the contract
     * @param _controlTower Address of the control tower
     */
    constructor(address _dao, IControlTower _controlTower) ERC20("Tangent USD", "USG") {
        owner = _dao;
        controlTower = _controlTower;
    }

    modifier onlyMarketCaller() {
        require(controlTower.isMarket(msg.sender), OnlyMarketCaller());
        _;
    }

    /**
     * @notice Markets call this function to mint USG when users borrow.
     * @dev    Only callable by a market
     * @param to     Receiver of the USG
     * @param amount Amount of USG borrowed to mint
     */
    function mint(address to, uint256 amount) external onlyMarketCaller {
        _mint(to, amount);
    }

    /**
     * @notice IRCalculator call this function to mint USG inflated through interests.
     * @dev    Only callable by an IRCalculator
     * @param amount Amount of USG borrowed to mint to the Fee Treasury
     */
    function mintIR(uint256 amount) external {
        (address _feeTreasury, bool isIRCalculator) = controlTower.getFeeTreasuryAndIsIRCalculator(msg.sender);
        require(isIRCalculator, OnlyIRCalculator());
        _mint(_feeTreasury, amount);
    }

    /**
     * @notice Mints USG on a pegKeeper.
     * @dev    Only callable by the DAO.
     * @param pegKeeper PegKeeper address to mint USG on
     * @param amount    Amount of USG to mint on the pegKeeper
     */
    function mintPegKeeper(address pegKeeper, uint256 amount) external onlyOwner {
        require(controlTower.isPegKeeper(pegKeeper), MintOnlyOnPegKeeper());
        _mint(pegKeeper, amount);
    }

    /**
     * @notice Markets call this function to burn USG when users repay their loans.
     * @dev    Only callable by the DAO
     * @param from      Address to burn the USG from
     * @param amount    Amount of USG to burn from the address
     */
    function burnFrom(address from, uint256 amount) external onlyMarketCaller {
        _burn(from, amount);
    }

    /**
     * @notice Burns USG of the caller
     * @dev    Callable by anyone that have USG.
     * @param amount Amount of USG to burn from the caller
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
