// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IControlTower} from "../../interfaces/internals/USG/IControlTower.sol";
import {LightOwnable} from "../Utilities/abstract/LightOwnable.sol";

/// @title WStable
/// @notice Wrapper for stable allowing to capture yield of underlying ERC4626.
contract WStable is ERC20, LightOwnable {
    uint256 constant MAX_UINT = uint256(int256(-1));
    uint256 public constant DENOMINATOR = 100_000;
    IControlTower public controlTower;

    IERC20Metadata public stable;
    IERC4626 public savingAccount;
    uint8 private _decimals;

    error NoRewardsToClaim();
    error ZeroAmount();

    constructor(string memory _name, string memory _symbol, IControlTower _controlTower, IERC20Metadata _stable, IERC4626 _savingAccount, address _owner) ERC20(_name, _symbol) {
        controlTower = _controlTower;
        stable = _stable;
        savingAccount = _savingAccount;
        // Match the decimals number
        _decimals = _stable.decimals();
        _stable.approve(address(_savingAccount), MAX_UINT);

        _transferOwnership(_owner);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     *  @notice Mints wStable against corresponding stable. A
     *  @param amountIn Amount of wStable to deposit in exchange of wStable
     *  @param receiver Receiver of the wStable
     *  @param isSaving For the sociabilization process
     */
    function mint(uint256 amountIn, address receiver, bool isSaving) public {
        require(amountIn != 0, ZeroAmount());

        uint256 amountToMint = amountIn;

        if (isSaving) {
            IERC4626 _savingAccount = savingAccount;
            amountToMint = _savingAccount.previewMint(amountIn);
            _savingAccount.transferFrom(msg.sender, address(this), amountIn);
        } else {
            stable.transferFrom(msg.sender, address(this), amountIn);
            savingAccount.deposit(amountIn, address(this));
        }

        // Mints the amount of WStable for the receiver
        _mint(receiver, amountToMint);
    }

    /**
     *  @notice          Mints wStable for Stable. Uses the mint function.
     *  @dev             This function has been created to match the ERC4626 and to be used in the Curve Router
     *  @param amountIn    Amount of stable to exchange for WStable. Always at 1:1 ratio.
     *  @param receiver  Receiver of the stable
     *  @return          Amount of WStable to receive and of Stable to send.
     */
    function deposit(uint256 amountIn, address receiver) external returns (uint256) {
        mint(amountIn, receiver, false);
        return amountIn;
    }

    /**
     *  @notice Burns the wStable from the sender and transfer back stable to the receiver.
     *  @dev    Pending stables on the wStable contract are the first to be send back to the user.
     *  @param amount    Amount of wStable to burn in exchange of stable. Always at 1:1 ratio.
     *  @param receiver  Receiver of the stable
     */
    function burn(uint256 amount, address receiver, bool isSaving) public {
        require(amount != 0, ZeroAmount());

        if (isSaving) {
            IERC4626 _savingAccount = savingAccount;
            _savingAccount.transfer(receiver, _savingAccount.previewWithdraw(amount));
        } else {
            savingAccount.withdraw(amount, receiver, address(this));
        }

        // Burn wStable from the sender
        _burn(msg.sender, amount);
    }

    /**
     *  @notice          Burns wStable for Stable. Uses the burn function
     *  @dev             This function has been created to match the ERC4626 and to be used in the Curve Router
     *  @param amount    Amount of WStable to burn in exchange of stable. Always at 1:1 ratio.
     *  @param receiver  Receiver of the stable
     *  @param owner     Param not used, keeped only to match the ERC4626 signature.
     *  @return          Amount of WStable to burn and of Stable to receive.
     */
    function redeem(uint256 amount, address receiver, address owner) external returns (uint256) {
        burn(amount, receiver, false);
        return amount;
    }

    /**
     *  @notice Claims all stable not due to user from the corresponding saving account
     *  @dev    Anyone can call this function
     */
    function claimRewards() external {
        IERC4626 _savingAccount = savingAccount;

        // Retrieve and sum the amount of stable farming on the saving account and the amount of pending stable.
        uint256 totalStableStaked = _savingAccount.maxWithdraw(address(this));
        // Retrieve the amount due to users.
        uint256 dueAmount = totalSupply();
        require(totalStableStaked > dueAmount, NoRewardsToClaim());

        // The delta between the total supply of wStable and the total amount withdrawable from savings is the amount of fee that we are taking
        _mint(controlTower.feeTreasury(), totalStableStaked - dueAmount);
    }

    function convertToAssets(uint256 shares) external pure returns (uint256) {
        return shares;
    }

    function convertToShares(uint256 assets) external pure returns (uint256) {
        return assets;
    }
}
