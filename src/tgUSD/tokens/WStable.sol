// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import {LightOwnable} from "../Utilities/LightOwnable.sol";
import "forge-std/console.sol";
/// @notice
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
     *  @notice Mints tgStable against corresponding stable. A
     *  @dev    When isStaked is true, the ratio of tgStable received / stable send is >= 1 as he'll take also all pending fees.
     *          When isStaked is false, the same ratio is < 1 as a fee is taken and deposited in the contract as "pending".
     *  @param amountIn Amount of tgStable to deposit in exchange of tgStable
     *  @param receiver Receiver of the tgStable
     *  @param isSaving For the sociabilization process
     */
    function mint(uint256 amountIn, address receiver, bool isSaving) public {
        require(amountIn != 0, ZeroAmount());

        uint256 amountToMint = amountIn;

        if (isSaving) {
            IERC4626 _savingAccount = savingAccount;
            amountToMint = _savingAccount.convertToAssets(amountIn);
            _savingAccount.transferFrom(msg.sender, address(this), amountIn);
        } else {
            stable.transferFrom(msg.sender, address(this), amountIn);
            savingAccount.deposit(amountIn, address(this));
        }

        // Computes the amount of tgStable to mint regarding 'isStaked'
        // Mints the amount of tgStable for the receiver
        _mint(receiver, amountToMint);
    }

    function convertToAssets(uint256 shares) external pure returns (uint256) {
        return shares;
    }

    function convertToShares(uint256 assets) external pure returns (uint256) {
        return assets;
    }

    //TODO Doc and test
    function deposit(uint256 amountIn, address receiver) external returns (uint256) {
        mint(amountIn, receiver, false);
        return amountIn;
    }

    /**
     *  @notice Burns the tgStable from the sender and transfer back stable to the receiver.
     *  @dev    Pending stables on the tgStable contract are the first to be send back to the user.
     *  @param amount    Amount of tgStable to burn in exchange of stable. Always at 1:1 ratio.
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

        // Burn tgStable from the sender
        _burn(msg.sender, amount);
    }
    //TODO Doc and test
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

        // We withdraw the amount missing from the saving account
        _savingAccount.withdraw(totalStableStaked - dueAmount, controlTower.feeTreasury(), address(this));
    }
}
