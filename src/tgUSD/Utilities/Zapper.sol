// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IOdosRouter} from "../../interfaces/externals/IOdosRouter.sol";
import {IMarketExternalActions} from "../../interfaces/internals/tgUSD/IMarketExternalActions.sol";
import {ICollateral} from "../../interfaces/internals/tgUSD/ICollateral.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import "forge-std/console.sol";

contract Zapper is Ownable {
    using SafeERC20 for IERC20;
    uint256 constant MAX_UINT = 2 ** 256 - 1;

    /// @notice Odos Router
    address public constant ROUTER_ODOS = 0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559;

    /// @notice Tangent USD
    IERC20 public tgUsd;

    /// @notice Control Tower
    IControlTower public controlTower;

    error OdosCallError();
    error MinAmountOutNotReached();
    error NotMarket(address market);
    error TokenInMustNotBeZero();
    error TokenInMustBeZero();

    constructor(address _owner, IControlTower _controlTower, IERC20 _tgUsd) Ownable(_owner) {
        tgUsd = _tgUsd;
        controlTower = _controlTower;
    }

    /**
     * @notice Throws if the market is not verified
     * @param  market address to verify
     */
    modifier onlyMarket(address market) {
        require(controlTower.isMarket(market), NotMarket(market));
        _;
    }

    struct ZapMarket {
        address market;
        address _for;
        IERC20 tokenIn;
        uint256 amountIn;
        uint256 minAmountOut;
    }

    /**
     *  @notice Zap any tokens against the collateral token of a Market.
     *          Then deposit this collateral for an account on the selected market.
     *  @param zapMarket A struct containing the market, _for, tokenIn, amountIn and the minAmountOut.
     *  @param odosCall  Raw data call used to call swap or swapMulti on the ODOS Router
     *  @param isStaked  If true and possible, will get pending sociabiliation fee and stake all pending collat for the whole market.
     *                   Otherwise, don't stake but the system takes a fee on the deposit.
     */
    function zapDeposit(ZapMarket calldata zapMarket, bytes calldata odosCall, bool isStaked) external payable {
        IMarketExternalActions(zapMarket.market).deposit(zapMarket._for, _zapDeposit(zapMarket, odosCall), isStaked);
    }

    /**
     *  @notice Zap any tokens against the collateral token of a Market.
     *          Then deposit this collateral for an account on the selected market.
     *  @param zapMarket      A struct containing the market, _for, tokenIn, amountIn and the minAmountOut.
     *  @param odosCall       Raw data call used to call swap or swapMulti on the ODOS Router
     *  @param tgUsdBorrowed  Amount of tgUSD to borrow
     *  @param isStaked       If true and possible, will get pending sociabiliation fee and stake all pending collat for the whole market.
     *                        Otherwise, don't stake but the system takes a fee on the deposit.
     */
    function zapDepositAndBorrow(ZapMarket calldata zapMarket, bytes calldata odosCall, uint256 tgUsdBorrowed, bool isStaked) external payable {
        IMarketExternalActions(zapMarket.market).depositAndBorrow(zapMarket._for, _zapDeposit(zapMarket, odosCall), tgUsdBorrowed, isStaked);
    }

    /**
     *  @notice Zap any tokens against tgUSD to cover partially or fully the debt of a position.
     *  @dev    Performs a zap through odos. All remaining tgUSD in case of a full repay stays on the caller.
     *  @param zapMarket A struct containing the market, _for, tokenIn, amountIn and the minAmountOut.
     *  @param odosCall  Raw data call used to call swap or swapMulti on the ODOS Router
     */
    function zapRepay(ZapMarket calldata zapMarket, bytes calldata odosCall) external payable {
        /// @dev Oui
        IMarketExternalActions(zapMarket.market).repay(zapMarket._for, _zapRepay(zapMarket, odosCall), msg.sender);
    }

    // function zapWithdrawAndRepay(ZapMarket calldata zapMarket, bytes calldata odosCall) external payable {
    //     IMarketExternalActions(zapMarket.market).repay(zapMarket._for, _zapRepay(zapMarket, odosCall));
    // }

    /**
     *  @notice Transfer tokens to the Zapper and Swap them through Odos against Collateral of the Market.
     *  @dev    Receiver of the collateral ise th market
     *  @param zapMarket A struct containing the market, _for, tokenIn, amountIn and the minAmountOut.
     *  @param odosCall  Raw data call used to call swap or swapMulti on the ODOS Router
     */
    function _zapDeposit(ZapMarket calldata zapMarket, bytes calldata odosCall) internal onlyMarket(zapMarket.market) returns (uint256) {
        _transferTokenToZapper(zapMarket.tokenIn, zapMarket.amountIn);
        return _zapOdosAndVerify(ICollateral(zapMarket.market).collatToken(), address(zapMarket.market), zapMarket.minAmountOut, odosCall);
    }

    /**
     *  @notice Transfer tokens to the Zapper and Swap them through Odos against tgUSD.
     *  @dev    Receiver of the tgUSD is the caller of the fun
     *  @param zapMarket A struct containing the market, _for, tokenIn, amountIn and the minAmountOut.
     *  @param odosCall  Raw data call used to call swap or swapMulti on the ODOS Router
     */
    function _zapRepay(ZapMarket calldata zapMarket, bytes calldata odosCall) internal onlyMarket(zapMarket.market) returns (uint256) {
        /// @dev Transfer ERC20 of native blockchain coin on this contract
        _transferTokenToZapper(zapMarket.tokenIn, zapMarket.amountIn);
        /// @dev Call Odos Router to swap the tokenIn to tgUSD and returns the out amount
        return _zapOdosAndVerify(tgUsd, msg.sender, zapMarket.minAmountOut, odosCall);
    }

    /**
     *  @notice Internal function transfering tokens to the Zapper and increasing allowance to Odos Router if necessary.
     *  @dev    Allowance are setup to infinite, no tokens are supposed to stay on the Zapper.
     *  @param tokenIn   Address of the tokenIn
     *  @param amountIn  Amount of token in to swap
     */
    function _transferTokenToZapper(IERC20 tokenIn, uint256 amountIn) internal {
        if (msg.value == 0) {
            require(address(tokenIn) != address(0), TokenInMustNotBeZero());
            if (amountIn > tokenIn.allowance(address(this), ROUTER_ODOS)) {
                tokenIn.approve(ROUTER_ODOS, MAX_UINT);
            }
            tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        } else {
            require(address(tokenIn) == address(0), TokenInMustBeZero());
        }
    }

    /**
     *  @notice Internal function Swaping tokens through Odos Router.
     *  @dev    Verifies the slippage and the validity of the call to Odos Router.
     *  @param tokenOut   Address of the token received after swap
     *  @param receiver  Amount of token in to swap
     *  @param minAmountOut  Amount of token in to swap
     *  @param odosData  Amount of token in to swap
     */
    function _zapOdosAndVerify(IERC20 tokenOut, address receiver, uint256 minAmountOut, bytes calldata odosData) internal returns (uint256) {
        /// @dev Retrieve the balance of the tokenOut before the Swap.
        uint256 amountOut = tokenOut.balanceOf(receiver);

        /// @dev Call Odos router and perform the swaps with raw data following recommendations.
        (bool isOdosCallSuccess, ) = ROUTER_ODOS.call{value: msg.value}(odosData);

        /// @dev Verify the call to Odos was successfull
        require(isOdosCallSuccess, OdosCallError());

        /// @dev Compute the amount of tokenOut returned by Odos thanks to previous value
        amountOut = tokenOut.balanceOf(receiver) - amountOut;

        /// @dev Verifies slippage to don't get less tokens than user expected
        require(amountOut >= minAmountOut, MinAmountOutNotReached());

        /// @dev Return the amount of token Out received
        return amountOut;
    }
}
