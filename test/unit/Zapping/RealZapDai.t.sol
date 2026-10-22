// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IZappingProxy} from "../../../src/interfaces/internals/USG/IZappingProxy.sol";
import {IControlTower} from "../../../src/interfaces/internals/USG/IControlTower.sol";
import {ZapStruct} from "../../../src/interfaces/internals/ICommonStruct.sol";

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

/// @notice End-to-end zap against the LIVE deployed ZappingProxy, the LIVE installed fallback
///         handler, and a REAL Uniswap V3 router and pool — no mocks anywhere in the path.
/// @dev    Also demonstrates the practical consequence of the fix: the DAI that has been stuck on
///         the proxy is swept out to the fee treasury by the next zap that touches DAI.
contract RealZapDaiTest is Test {
    /// @dev After the Safe transaction that installed the handler.
    uint256 internal constant FORK_BLOCK = 25687255;

    address internal constant OWNER_SAFE = 0x461B62CB3A7e9Df8f800aE058AE92F855F2c27Ca;
    address internal constant DEPLOYED_HANDLER = 0x055E53A75598E570ad7970AF4Cd34E3877817dCf;
    address internal constant CONTROL_TOWER = 0xF3f7669dcEED2f985815011C19eD68F667267215;
    address internal constant CANONICAL_HANDLER = 0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99;
    bytes32 internal constant FALLBACK_HANDLER_SLOT = 0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5;

    IZappingProxy internal constant ZAPPING_PROXY = IZappingProxy(0xA9E0021d8917C51F496823605d218d7E78719c99);
    ISwapRouter02 internal constant UNIV3_ROUTER = ISwapRouter02(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);

    IERC20 internal constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 internal constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    uint24 internal constant POOL_FEE = 100; // DAI/USDC 0.01%

    address internal receiver = makeAddr("zapReceiver");
    address internal feeTreasury;
    uint256 internal stuckDai;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);

        // Sanity: the fix really is installed on the Safe at this block.
        assertEq(
            address(uint160(uint256(vm.load(OWNER_SAFE, FALLBACK_HANDLER_SLOT)))),
            DEPLOYED_HANDLER,
            "handler not installed at fork block"
        );

        feeTreasury = IControlTower(CONTROL_TOWER).feeTreasury();
        stuckDai = DAI.balanceOf(address(ZAPPING_PROXY));
        assertGt(stuckDai, 0, "no DAI stuck on the proxy at this block");
    }

    function _zapCall(uint256 amountIn, uint256 minOut) internal view returns (ZapStruct memory) {
        return
            ZapStruct({
                router: address(UNIV3_ROUTER),
                routerCall: abi.encodeCall(
                    ISwapRouter02.exactInputSingle,
                    (
                        ISwapRouter02.ExactInputSingleParams({
                            tokenIn: address(DAI),
                            tokenOut: address(USDC),
                            fee: POOL_FEE,
                            recipient: receiver,
                            amountIn: amountIn,
                            amountOutMinimum: minOut,
                            sqrtPriceLimitX96: 0
                        })
                    )
                )
            });
    }

    /// @notice A realistic-size DAI -> USDC zap through the real Uniswap V3 pool. The pre-existing
    ///         stuck DAI is swept to the fee treasury as part of the same transaction.
    function test_realZap_daiToUsdc_sweepsStuckDai() public {
        uint256 amountIn = 10_000e18;
        deal(address(DAI), address(ZAPPING_PROXY), stuckDai + amountIn);

        uint256 treasuryBefore = DAI.balanceOf(feeTreasury);

        uint256 received = ZAPPING_PROXY.zapProxy(DAI, USDC, 9_900e6, receiver, _zapCall(amountIn, 9_900e6));

        emit log_named_decimal_uint("DAI swapped     ", amountIn, 18);
        emit log_named_decimal_uint("USDC received   ", received, 6);
        emit log_named_decimal_uint("stuck DAI swept ", stuckDai, 18);

        assertEq(USDC.balanceOf(receiver), received, "receiver USDC mismatch");
        assertGt(received, 9_900e6, "unrealistic output");
        assertEq(DAI.balanceOf(feeTreasury) - treasuryBefore, stuckDai, "stuck DAI did not reach treasury");
        assertEq(DAI.balanceOf(address(ZAPPING_PROXY)), 0, "DAI left on proxy");
    }

    /// @notice The same zap, but spending ONLY the DAI actually sitting on the proxy today — no
    ///         `deal`, no top-up. Proves the real stuck balance is usable and routable.
    function test_realZap_usingOnlyTheStuckDai() public {
        uint256 spend = stuckDai / 2;
        uint256 treasuryBefore = DAI.balanceOf(feeTreasury);

        // Sub-microdollar input: the pool legitimately returns 0 USDC after rounding, so the only
        // meaningful assertion is that the call succeeds and the remainder is swept.
        ZAPPING_PROXY.zapProxy(DAI, USDC, 0, receiver, _zapCall(spend, 0));

        assertEq(DAI.balanceOf(feeTreasury) - treasuryBefore, stuckDai - spend, "remainder not swept");
        assertEq(DAI.balanceOf(address(ZAPPING_PROXY)), 0, "DAI left on proxy");
    }

    /// @notice The same real zap against the PRE-FIX Safe: it must revert, confirming the stuck DAI
    ///         was genuinely unroutable before the handler was installed.
    function test_realZap_wouldHaveRevertedBeforeTheFix() public {
        vm.prank(OWNER_SAFE);
        (bool ok, ) = OWNER_SAFE.call(abi.encodeWithSignature("setFallbackHandler(address)", CANONICAL_HANDLER));
        assertTrue(ok, "failed to restore canonical handler");

        uint256 amountIn = 10_000e18;
        deal(address(DAI), address(ZAPPING_PROXY), stuckDai + amountIn);

        vm.expectRevert();
        ZAPPING_PROXY.zapProxy(DAI, USDC, 9_900e6, receiver, _zapCall(amountIn, 9_900e6));
    }
}
