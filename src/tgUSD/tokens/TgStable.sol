// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import {Sociabilization} from "../Utilities/Sociabilization.sol";

import "forge-std/console.sol";
/// @notice
contract TgStable is ERC20, Sociabilization {
    uint256 constant MAX_UINT = uint256(int256(-1));
    uint256 public constant DENOMINATOR = 100_000;
    IControlTower public controlTower;

    IERC20Metadata public stable;
    IERC4626 public savingAccount;
    uint8 private _decimals;

    error NoRewardsToClaim();
    error ZeroAmount();

    constructor(
        string memory _name,
        string memory _symbol,
        IControlTower _controlTower,
        IERC20Metadata _stable,
        IERC4626 _savingAccount,
        address _owner,
        uint256 _socFeePercentage
    ) ERC20(_name, _symbol) {
        controlTower = _controlTower;
        stable = _stable;
        savingAccount = _savingAccount;
        // Match the decimals number
        _decimals = _stable.decimals();
        _stable.approve(address(_savingAccount), MAX_UINT);

        _transferOwnership(_owner);

        // Sociabilization
        require(_socFeePercentage <= 2_000, SocFeeTooHigh());
        socFeePercentage = _socFeePercentage;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     *  @notice Mints tgStable against corresponding stable. A
     *  @dev    When isStaked is true, the ratio of tgStable received / stable send is >= 1 as he'll take also all pending fees.
     *          When isStaked is false, the same ratio is < 1 as a fee is taken and deposited in the contract as "pending".
     *  @param to       Receiver of the tgStable
     *  @param amountIn Amount of tgStable to deposit in exchange of tgStable
     *  @param isStaked For the sociabilization process
     */
    function mint(address to, uint256 amountIn, bool isStaked) external {
        require(amountIn != 0, ZeroAmount());
        IERC20 _stable = stable;
        // Transfer the stable from the user on tgUSD
        _stable.transferFrom(msg.sender, address(this), amountIn);

        // Computes the amount of tgStable to mint regarding 'isStaked'
        // Mints the amount of tgStable for the receiver
        _mint(to, _sociabilizationProcess(amountIn, isStaked, DENOMINATOR));

        if (isStaked) {
            // Stakes all pending stable in the saving account
            savingAccount.deposit(_stable.balanceOf(address(this)), address(this));
        }
    }

    /**
     *  @notice Burns the tgStable from the sender and transfer back stable to the receiver.
     *  @dev    Pending stables on the tgStable contract are the first to be send back to the user.
     *  @param receiver  Receiver of the stable
     *  @param amount    Amount of tgStable to burn in exchange of stable. Always at 1:1 ratio.
     */
    function burn(address receiver, uint256 amount) external {
        require(amount != 0, ZeroAmount());

        IERC20 _stable = stable;

        // Burn tgStable from the sender
        _burn(msg.sender, amount);

        uint256 stableBalance = _stable.balanceOf(address(this));

        // If not enough stable on the tgStable
        if (stableBalance < amount) {
            // We withdraw what misses from the Vault
            savingAccount.withdraw(amount - stableBalance, address(this), address(this));
        }
        // Transfer the stable to the receiver
        _stable.transfer(receiver, amount);
    }

    /**
     *  @notice Stakes all pending stables.
     *  @dev    Anyone can call this function
     *  @param  receiver Receiver of the fees in stable
     */
    function stakesAll(address receiver) external {
        IERC20 _stable = stable;
        _stable.transfer(receiver, socFeePending);
        savingAccount.deposit(_stable.balanceOf(address(this)), address(this));
        delete socFeePending;
    }

    /**
     *  @notice Claims all stable not due to user from the corresponding saving account
     *  @dev    Anyone can call this function
     */
    function claimRewards() external {
        IERC4626 _savingAccount = savingAccount;
        IERC20 _stable = stable;

        uint256 stableBalance = _stable.balanceOf(address(this));

        // Retrieve and sum the amount of stable farming on the saving account and the amount of pending stable.
        uint256 totalStableStaked = _savingAccount.maxWithdraw(address(this)) + stableBalance;
        // Retrieve the amount due to users.
        uint256 dueAmount = totalSupply();
        require(totalStableStaked > dueAmount, NoRewardsToClaim());
        uint256 claimableAmount = totalStableStaked - dueAmount;

        // If there is not enough stable on the contract to be send directly
        if (claimableAmount > stableBalance) {
            // We withdraw the amount missing from the saving account
            _savingAccount.withdraw(claimableAmount - stableBalance, address(this), address(this));
        }

        // Sends claimable stablecoin to the Fee Treasury
        _stable.transfer(controlTower.feeTreasury(), claimableAmount);

        // Retrieve the balance in stable on tgStable after rewards distribution
        stableBalance = _stable.balanceOf(address(this));

        if (stableBalance != 0) {
            // Stake all the balance that left in the contract
            _savingAccount.deposit(stableBalance, address(this));
        }
        // Delete the sociabilization fees
        delete socFeePending;
    }
}
