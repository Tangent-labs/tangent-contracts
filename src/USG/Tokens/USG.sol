// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IUSG} from "../../interfaces/internals/USG/IUSG.sol";
import {IControlTower} from "../../interfaces/internals/USG/IControlTower.sol";
import {LightOwnable} from "../../USG/Utilities/abstract/LightOwnable.sol";

/// @title Tangent USG
/// @author Tangent Finance
/// @notice Locking NFT contract of TAN.
contract USG is ERC20, IUSG, LightOwnable {
    IControlTower public controlTower;

    mapping(address => bool) public isMinter;

    mapping(address => bool) public isBurner;

    mapping(address => bool) public isIRProducer;

    mapping(address => bool) public isPegKeeper;

    error OnlyMinterCaller();
    error OnlyBurnerCaller();
    error OnlyIRProducer();
    error OnlyMarketCreator();
    error MintOnlyOnPegKeeper();
    error BurnOnlyFromPegKeeper();

    event SetIsMinter(address minter, bool isMinter);
    event SetIsBurner(address burner, bool isBurner);
    event SetIsIRProducer(address irProducer, bool isIRProducer);
    event SetIsPegKeeper(address pegKeeper, bool isPegKeeper);

    /**
     * @notice Constructor of USG
     * @param _dao           Address of the DAO that becomes the owner of the contract
     * @param _controlTower Address of the control tower
     */
    constructor(address _dao, IControlTower _controlTower) ERC20("Tangent USD", "USG") {
        owner = _dao;
        controlTower = _controlTower;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        MINT
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Markets call this function to mint USG when users borrow.
     * @param to     Receiver of the USG
     * @param amount Amount of USG borrowed to mint
     */
    function mintDebt(address to, uint256 amount) external {
        require(isMinter[msg.sender], OnlyMinterCaller());
        _mint(to, amount);
    }

    /**
     * @notice IRCalculator call this function to mint USG inflated through interests.
     * @dev    Only callable by an ir producer
     * @param amount Amount of USG produced by interest rate since last mint on the
     */
    function mintIR(uint256 amount) external {
        require(isIRProducer[msg.sender], OnlyIRProducer());
        _mint(controlTower.feeTreasury(), amount);
    }

    /**
     * @notice Mints USG on a pegKeeper to be able to provide LP in USG in case USG is overpeg.
     * @dev    Only callable by the DAO.
     * @param pegKeeper PegKeeper address to mint USG on
     * @param amount    Amount of USG to mint on the pegKeeper
     */
    function mintPegKeeper(address pegKeeper, uint256 amount) external onlyOwner {
        require(isPegKeeper[pegKeeper], MintOnlyOnPegKeeper());
        _mint(pegKeeper, amount);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        BURN
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     * @notice Markets call this function to burn USG when users repay their loans.
     * @param from    Address to burn the USG from
     * @param amount  Amount of USG to burn from the address
     */
    function burnDebt(address from, uint256 amount) external {
        require(isBurner[msg.sender], OnlyBurnerCaller());
        _burn(from, amount);
    }

    /**
     * @notice Burn USG from a pegKeeper if we deprecate a pegkeeper or want to reduce debt to be allocated to peg keeping
     * @dev    Only callable by the DAO.
     * @param pegKeeper PegKeeper address to burn USG from
     * @param amount    Amount of USG to burn from the pegKeeper
     */
    function burnPegKeeper(address pegKeeper, uint256 amount) external onlyOwner {
        require(isPegKeeper[pegKeeper], BurnOnlyFromPegKeeper());
        _burn(pegKeeper, amount);
    }

    /**
     * @notice Burns USG of the caller
     * @dev    Callable by anyone that have USG.
     * @param amount Amount of USG to burn from the caller
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        SETTERS
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    /**
     *  @notice Called by a Market Creator to set a new market as minter and burner
     *  @param  market  Address set as minter and burner
     */
    function initializeMarket(address market) external {
        require(controlTower.isMarketCreator(msg.sender), OnlyMarketCreator());
        isMinter[market] = true;
        isBurner[market] = true;
    }

    /**
     * @notice Adds or removes an address from the minter role.
     * @dev Updates the `isMinter` mapping. Callable only by the contract owner.
     * @param minter    The address whose minter status will be updated.
     * @param _isMinter `true` to assign the minter role, `false` to revoke it.
     */
    function setIsMinter(address minter, bool _isMinter) external onlyOwner {
        isMinter[minter] = _isMinter;
        emit SetIsMinter(minter, _isMinter);
    }

    /**
     * @notice Adds or removes an address from the burner role.
     * @dev Updates the `isBurner` mapping. Callable only by the contract owner.
     * @param burner    The address whose burner status will be updated.
     * @param _isBurner `true` to assign the burner role, `false` to revoke it.
     */
    function setIsBurner(address burner, bool _isBurner) external onlyOwner {
        isBurner[burner] = _isBurner;
        emit SetIsBurner(burner, _isBurner);
    }

    /**
     * @notice Adds or removes an address from the ir producer role.
     * @dev Updates the `isIRProducer` mapping. Callable only by the contract owner.
     * @param irProducer    The address whose ir Producer status will be updated.
     * @param _isIRProducer `true` to assign the ir producer role, `false` to revoke it.
     */
    function setIsIRProducer(address irProducer, bool _isIRProducer) external onlyOwner {
        isIRProducer[irProducer] = _isIRProducer;
        emit SetIsIRProducer(irProducer, _isIRProducer);
    }

    /**
     * @notice Adds or removes an address from the peg keeper role.
     * @dev Updates the `isPegKeeper` mapping. Callable only by the contract owner.
     * @param pegKeeper    The address whose peg keeper status will be updated.
     * @param _isPegKeeper `true` to assign the peg keeper role, `false` to revoke it.
     */
    function setIsPegKeeper(address pegKeeper, bool _isPegKeeper) external onlyOwner {
        isPegKeeper[pegKeeper] = _isPegKeeper;
        emit SetIsPegKeeper(pegKeeper, _isPegKeeper);
    }
}
