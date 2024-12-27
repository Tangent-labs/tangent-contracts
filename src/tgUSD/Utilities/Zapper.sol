// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IMarketExternalActions} from "../../interfaces/internals/tgUSD/IMarketExternalActions.sol";
import {ICollateral} from "../../interfaces/internals/tgUSD/ICollateral.sol";
import {IControlTower} from "../../interfaces/internals/tgUSD/IControlTower.sol";
import {ITgUSD} from "../../interfaces/internals/tgUSD/ITgUSD.sol";
import {IZapper} from "../../interfaces/internals/tgUSD/IZapper.sol";
import "forge-std/console.sol";

contract Zapper is Ownable, IZapper {
    using SafeERC20 for IERC20;
    uint256 constant MAX_UINT = 2 ** 256 - 1;

    address constant CHAIN_COIN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice Router
    address public constant ROUTER = 0x80EbA3855878739F4710233A8a19d89Bdd2ffB8E;

    /// @notice Tangent USD
    ITgUSD public tgUsd;

    /// @notice Control Tower
    IControlTower public controlTower;

    error RouterCallError();
    error MinAmountOutNotReached();
    error NotMarket(address market);
    error TokenInMustNotBeZero();
    error TokenInMustBeZero();

    constructor(address _owner, IControlTower _controlTower, ITgUSD _tgUsd) Ownable(_owner) {
        tgUsd = _tgUsd;
        controlTower = _controlTower;

        _tgUsd.approve(ROUTER, MAX_UINT);
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
     *  @param routerCall  Raw data call used to call swap or swapMulti on the router Router
     *  @param isStaked  If true and possible, will get pending sociabiliation fee and stake all pending collat for the whole market.
     *                   Otherwise, don't stake but the system takes a fee on the deposit.
     */
    function zapDeposit(ZapMarket calldata zapMarket, bytes calldata routerCall, bool isStaked) external payable {
        IMarketExternalActions(zapMarket.market).deposit(zapMarket._for, _zapDeposit(zapMarket, routerCall), isStaked);
    }

    /**
     *  @notice Zap any tokens against the collateral token of a Market.
     *          Then deposit this collateral for an account on the selected market.
     *  @param zapMarket      A struct containing the market, _for, tokenIn, amountIn and the minAmountOut.
     *  @param routerCall       Raw data call used to call swap or swapMulti on the router Router
     *  @param tgUsdBorrowed  Amount of tgUSD to borrow
     *  @param isStaked       If true and possible, will get pending sociabiliation fee and stake all pending collat for the whole market.
     *                        Otherwise, don't stake but the system takes a fee on the deposit.
     */
    function zapDepositAndBorrow(ZapMarket calldata zapMarket, bytes calldata routerCall, uint256 tgUsdBorrowed, bool isStaked) external payable {
        IMarketExternalActions(zapMarket.market).depositAndBorrow(_zapDeposit(zapMarket, routerCall), tgUsdBorrowed, isStaked, msg.sender);
    }

    /**
     *  @notice Zap any tokens against tgUSD to cover partially or fully the debt of a position.
     *  @dev    Performs a zap through router. All remaining tgUSD in case of a full repay stays on the caller.
     *  @param zapMarket A struct containing the market, _for, tokenIn, amountIn and the minAmountOut.
     *  @param routerCall  Raw data call used to call swap or swapMulti on the router Router
     */
    function zapRepay(ZapMarket calldata zapMarket, bytes calldata routerCall) external payable {
        IMarketExternalActions(zapMarket.market).repay(zapMarket._for, _zapRepay(zapMarket, routerCall), msg.sender);
    }

    // function zapWithdrawAndRepay(ZapMarket calldata zapMarket, bytes calldata routerCall) external payable {
    //     IMarketExternalActions(zapMarket.market).repay(zapMarket._for, _zapRepay(zapMarket, routerCall));
    // }

    function zapLeverage(IERC20 collatToken, uint256 minCollatReceived, bytes calldata routerCall) external onlyMarket(msg.sender) returns (uint256) {
        return _zapRouterAndVerify(collatToken, msg.sender, minCollatReceived, routerCall);
    }

    /**
     *  @notice Transfer tokens to the Zapper and Swap them through router against Collateral of the Market.
     *  @dev    Receiver of the collateral ise th market
     *  @param zapMarket A struct containing the market, _for, tokenIn, amountIn and the minAmountOut.
     *  @param routerCall  Raw data call used to call swap or swapMulti on the router Router
     */
    function _zapDeposit(ZapMarket calldata zapMarket, bytes calldata routerCall) internal onlyMarket(zapMarket.market) returns (uint256) {
        _transferTokenToZapper(zapMarket.tokenIn, zapMarket.amountIn);
        return _zapRouterAndVerify(ICollateral(zapMarket.market).collatToken(), address(zapMarket.market), zapMarket.minAmountOut, routerCall);
    }

    /**
     *  @notice Transfer tokens to the Zapper and Swap them through router against tgUSD.
     *  @dev    Receiver of the tgUSD is the caller of the fun
     *  @param zapMarket A struct containing the market, _for, tokenIn, amountIn and the minAmountOut.
     *  @param routerCall  Raw data call used to call swap or swapMulti on the router Router
     */
    function _zapRepay(ZapMarket calldata zapMarket, bytes calldata routerCall) internal onlyMarket(zapMarket.market) returns (uint256) {
        // Transfer ERC20 of native blockchain coin on this contract
        _transferTokenToZapper(zapMarket.tokenIn, zapMarket.amountIn);
        // Call router Router to swap the tokenIn to tgUSD and returns the out amount
        return _zapRouterAndVerify(tgUsd, msg.sender, zapMarket.minAmountOut, routerCall);
    }

    /**
     *  @notice Internal function transfering tokens to the Zapper and increasing allowance to router Router if necessary.
     *  @dev    Allowance are setup to infinite, no tokens are supposed to stay on the Zapper.
     *  @param tokenIn   Address of the tokenIn
     *  @param amountIn  Amount of token in to swap
     */
    function _transferTokenToZapper(IERC20 tokenIn, uint256 amountIn) internal {
        // When no native coin are send, it means we are Zaping an ERC20
        if (msg.value == 0) {
            // TokenIn in param must different from 0
            require(address(tokenIn) != CHAIN_COIN, TokenInMustNotBeZero());
            // If the Zapper never approved the router
            if (amountIn > tokenIn.allowance(address(this), ROUTER)) {
                tokenIn.forceApprove(ROUTER, MAX_UINT);
            }
            tokenIn.safeTransferFrom(msg.sender, address(this), amountIn);
        } else {
            require(address(tokenIn) == CHAIN_COIN, TokenInMustBeZero());
        }
    }

    /**
     *  @notice Internal function Swaping tokens through router Router.
     *  @dev    Verifies the slippage and the validity of the call to router Router.
     *  @param tokenOut   Address of the token received after swap
     *  @param receiver  Amount of token in to swap
     *  @param minAmountOut  Amount of token in to swap
     *  @param routerData  Amount of token in to swap
     */
    function _zapRouterAndVerify(IERC20 tokenOut, address receiver, uint256 minAmountOut, bytes calldata routerData) internal returns (uint256) {
        // Retrieve the balance of the tokenOut before the Swap.
        uint256 amountOut = tokenOut.balanceOf(receiver);

        // Call router router and perform the swaps with raw data following recommendations.
        (bool isrouterCallSuccess, ) = ROUTER.call{value: msg.value}(routerData);
        // Verify the call to router was successfull
        require(isrouterCallSuccess, RouterCallError());
        // Compute the amount of tokenOut returned by router thanks to previous value
        amountOut = tokenOut.balanceOf(receiver) - amountOut;
        // Verifies slippage to don't get less tokens than user expected
        require(amountOut >= minAmountOut, MinAmountOutNotReached());
        // Return the amount of token Out received
        return amountOut;
    }
}
