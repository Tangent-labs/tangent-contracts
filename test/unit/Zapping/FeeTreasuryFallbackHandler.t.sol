// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {FeeTreasuryFallbackHandler} from "../../../src/USG/Utilities/FeeTreasuryFallbackHandler.sol";
import {IZappingProxy} from "../../../src/interfaces/internals/USG/IZappingProxy.sol";
import {IControlTower} from "../../../src/interfaces/internals/USG/IControlTower.sol";
import {ZapStruct} from "../../../src/interfaces/internals/ICommonStruct.sol";

interface ISafeFallbackManager {
    function setFallbackHandler(address handler) external;
}

interface IControlTowerAdmin {
    function setFeeTreasury(address feeTreasury) external;
}

/// @notice Minimal router used to exercise the ZappingProxy dust paths deterministically.
contract MockRouter {
    /// @notice Pulls `amountIn` of tokenIn from the caller and pays `amountOut` of tokenOut to `receiver`.
    function swap(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut, uint256 amountOut, address receiver) external {
        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        tokenOut.transfer(receiver, amountOut);
    }

    /// @notice Consumes part of the forwarded ETH, refunds `refund` to the caller, pays tokenOut to `receiver`.
    function swapEth(IERC20 tokenOut, uint256 amountOut, address receiver, uint256 refund) external payable {
        tokenOut.transfer(receiver, amountOut);
        (bool isSuccess, ) = msg.sender.call{value: refund}("");
        require(isSuccess, "refund failed");
    }

    receive() external payable {}
}

/// @notice Fork tests for the FeeTreasuryFallbackHandler remediation.
/// @dev    The live ZappingProxy was deployed with the owner Safe as its `controlTower`. Installing
///         this handler on that Safe makes `controlTower.feeTreasury()` resolve, unblocking every
///         zap that leaves dust behind. These tests run against the real deployed bytecode.
contract FeeTreasuryFallbackHandlerTest is Test {
    // keccak256("fallback_manager.handler.address")
    bytes32 internal constant FALLBACK_HANDLER_SLOT = 0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5;

    address internal constant OWNER_SAFE = 0x461B62CB3A7e9Df8f800aE058AE92F855F2c27Ca;
    address internal constant CONTROL_TOWER = 0xF3f7669dcEED2f985815011C19eD68F667267215;
    address internal constant FEE_TREASURY = 0x536d4e9C0944dE2aC6657d610Aa99fA5e97Ce493;
    address internal constant CANONICAL_HANDLER = 0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99;

    IZappingProxy internal constant ZAPPING_PROXY = IZappingProxy(0xA9E0021d8917C51F496823605d218d7E78719c99);

    IERC20 internal constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 internal constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address internal constant CHAIN_COIN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @dev Pinned after the handler deployment AND after the Safe transaction that installed it.
    uint256 internal constant FORK_BLOCK = 25687255;

    FeeTreasuryFallbackHandler internal handler;
    MockRouter internal router;
    address internal receiver = makeAddr("receiver");

    /// @dev The fallback handler the Safe is really running at FORK_BLOCK, captured before the
    ///      baseline is normalised below.
    address internal liveHandlerAtFork;

    function setUp() public {
        vm.createSelectFork("mainnet", FORK_BLOCK);
        liveHandlerAtFork = address(uint160(uint256(vm.load(OWNER_SAFE, FALLBACK_HANDLER_SLOT))));

        // Restore the pre-fix baseline in-fork so "before vs after" parity checks stay meaningful
        // now that the real Safe already runs the new handler.
        vm.prank(OWNER_SAFE);
        ISafeFallbackManager(OWNER_SAFE).setFallbackHandler(CANONICAL_HANDLER);

        handler = _handlerUnderTest();
        router = new MockRouter();

        vm.label(OWNER_SAFE, "OwnerSafe");
        vm.label(FEE_TREASURY, "FeeTreasury");
        vm.label(address(ZAPPING_PROXY), "ZappingProxy");
    }

    /// @dev Overridden by the deployed-bytecode suite to point at the live handler instead.
    function _handlerUnderTest() internal virtual returns (FeeTreasuryFallbackHandler) {
        return new FeeTreasuryFallbackHandler(IControlTower(CONTROL_TOWER));
    }

    /// @dev Installs the handler through the real `setFallbackHandler`, which is `authorized`
    ///      (self-call only) — pranking as the Safe reproduces the execTransaction call frame.
    function _installHandler() internal {
        vm.prank(OWNER_SAFE);
        ISafeFallbackManager(OWNER_SAFE).setFallbackHandler(address(handler));
    }

    // ---------------------------------------------------------------- preconditions

    function test_liveProxyPointsAtTheSafe() public view {
        assertEq(address(ZAPPING_PROXY).code.length > 0, true, "proxy has no code");
        (, bytes memory data) = address(ZAPPING_PROXY).staticcall(abi.encodeWithSignature("controlTower()"));
        assertEq(abi.decode(data, (address)), OWNER_SAFE, "proxy no longer misconfigured");
        assertEq(IControlTower(CONTROL_TOWER).feeTreasury(), FEE_TREASURY, "unexpected feeTreasury");
    }

    /// @dev Records what the Safe is actually running on mainnet at FORK_BLOCK.
    function test_liveSafeHandler() public view {
        assertEq(liveHandlerAtFork, 0x055E53A75598E570ad7970AF4Cd34E3877817dCf, "unexpected live handler");
    }

    function test_feeTreasuryRevertsBeforeFix() public {
        vm.expectRevert();
        IControlTower(OWNER_SAFE).feeTreasury();
    }

    // ---------------------------------------------------------------- the fix

    function test_feeTreasuryResolvesThroughSafeAfterFix() public {
        _installHandler();
        assertEq(IControlTower(OWNER_SAFE).feeTreasury(), FEE_TREASURY);
    }

    function test_handlerCannotBeConstructedWithZeroAddress() public {
        vm.expectRevert(FeeTreasuryFallbackHandler.ZeroAddress.selector);
        new FeeTreasuryFallbackHandler(IControlTower(address(0)));
    }



    // ---------------------------------------------------------------- flexibility preserved

    /// @notice The whole point of delegating rather than hardcoding: rotating the treasury on the
    ///         ControlTower must be reflected through the Safe with no handler redeploy.
    /// @dev    `setFeeTreasury` is `onlyOwner` and the ControlTower owner is this very Safe, so this
    ///         exercises the real governance path rather than a mock.
    function test_feeTreasuryRotationIsReflectedLive() public {
        _installHandler();
        assertEq(IControlTower(OWNER_SAFE).feeTreasury(), FEE_TREASURY, "wrong initial treasury");

        address newTreasury = makeAddr("newTreasury");
        vm.prank(OWNER_SAFE);
        IControlTowerAdmin(CONTROL_TOWER).setFeeTreasury(newTreasury);

        assertEq(IControlTower(OWNER_SAFE).feeTreasury(), newTreasury, "rotation not reflected");
    }

    /// @dev A rotated treasury must actually receive the dust, end to end through the live proxy.
    function test_dustFollowsRotatedTreasury() public {
        _installHandler();

        address newTreasury = makeAddr("newTreasury");
        vm.prank(OWNER_SAFE);
        IControlTowerAdmin(CONTROL_TOWER).setFeeTreasury(newTreasury);

        (ZapStruct memory zap, uint256 amountOut, uint256 dust) = _prepareErc20Zap();
        ZAPPING_PROXY.zapProxy(USDC, WETH, amountOut, receiver, zap);

        assertEq(USDC.balanceOf(newTreasury), dust, "dust did not follow the rotation");
        assertEq(USDC.balanceOf(address(ZAPPING_PROXY)), 0, "dust left in proxy");
    }

    /// @notice DOCUMENTED EXPOSURE, not a guard: the handler passes the ControlTower's answer
    ///         through unchecked, so a zeroed `feeTreasury` makes ZappingProxy send ETH dust to
    ///         address(0) with a low-level call — which SUCCEEDS, silently burning it.
    /// @dev    This is pre-existing ZappingProxy behaviour, identical to what a correctly wired
    ///         ControlTower would produce; the handler neither introduces nor mitigates it. Pinned
    ///         so the exposure is visible and any future change is caught.
    function test_zeroedTreasuryBurnsEthDust() public {
        _installHandler();

        vm.prank(OWNER_SAFE);
        IControlTowerAdmin(CONTROL_TOWER).setFeeTreasury(address(0));

        (ZapStruct memory zap, uint256 amountIn, uint256 amountOut, uint256 dust) = _prepareEthZap();
        uint256 burnedBefore = address(0).balance;

        ZAPPING_PROXY.zapProxy{value: amountIn}(IERC20(CHAIN_COIN), USDC, amountOut, receiver, zap);

        assertEq(address(0).balance - burnedBefore, dust, "ETH dust was not sent to address(0)");
        assertEq(address(ZAPPING_PROXY).balance, 0, "ETH left in proxy");
    }

    /// @dev The ERC20 dust path is safe under the same condition: OZ SafeERC20 reverts on a
    ///      transfer to address(0), so tokens are never burned.
    function test_zeroedTreasuryRevertsErc20Dust() public {
        _installHandler();

        vm.prank(OWNER_SAFE);
        IControlTowerAdmin(CONTROL_TOWER).setFeeTreasury(address(0));

        (ZapStruct memory zap, uint256 amountOut, ) = _prepareErc20Zap();
        vm.expectRevert();
        ZAPPING_PROXY.zapProxy(USDC, WETH, amountOut, receiver, zap);
    }

    // ---------------------------------------------------------------- ERC20 dust path

    function test_erc20DustRevertsBeforeFix() public {
        (ZapStruct memory zap, uint256 amountOut, ) = _prepareErc20Zap();

        vm.expectRevert();
        ZAPPING_PROXY.zapProxy(USDC, WETH, amountOut, receiver, zap);
    }

    function test_erc20DustReachesFeeTreasuryAfterFix() public {
        _installHandler();
        (ZapStruct memory zap, uint256 amountOut, uint256 dust) = _prepareErc20Zap();
        uint256 treasuryBefore = USDC.balanceOf(FEE_TREASURY);

        ZAPPING_PROXY.zapProxy(USDC, WETH, amountOut, receiver, zap);

        assertEq(WETH.balanceOf(receiver), amountOut, "receiver did not get tokenOut");
        assertEq(USDC.balanceOf(FEE_TREASURY) - treasuryBefore, dust, "dust did not reach treasury");
        assertEq(USDC.balanceOf(address(ZAPPING_PROXY)), 0, "dust left in proxy");
    }

    /// @dev Deals USDC to the proxy and builds a swap that spends only part of it, leaving dust.
    function _prepareErc20Zap() internal returns (ZapStruct memory zap, uint256 amountOut, uint256 dust) {
        uint256 amountIn = 1_000e6;
        uint256 spent = 900e6;
        amountOut = 0.2 ether;
        dust = amountIn - spent;

        deal(address(USDC), address(ZAPPING_PROXY), amountIn);
        deal(address(WETH), address(router), amountOut);

        zap = ZapStruct({
            router: address(router),
            routerCall: abi.encodeCall(MockRouter.swap, (USDC, spent, WETH, amountOut, receiver))
        });
    }

    // ---------------------------------------------------------------- ETH dust path

    function test_ethDustRevertsBeforeFix() public {
        (ZapStruct memory zap, uint256 amountIn, uint256 amountOut, ) = _prepareEthZap();

        vm.expectRevert();
        ZAPPING_PROXY.zapProxy{value: amountIn}(IERC20(CHAIN_COIN), USDC, amountOut, receiver, zap);
    }

    function test_ethDustReachesFeeTreasuryAfterFix() public {
        _installHandler();
        (ZapStruct memory zap, uint256 amountIn, uint256 amountOut, uint256 dust) = _prepareEthZap();
        uint256 treasuryBefore = FEE_TREASURY.balance;

        ZAPPING_PROXY.zapProxy{value: amountIn}(IERC20(CHAIN_COIN), USDC, amountOut, receiver, zap);

        assertEq(USDC.balanceOf(receiver), amountOut, "receiver did not get tokenOut");
        assertEq(FEE_TREASURY.balance - treasuryBefore, dust, "ETH dust did not reach treasury");
        assertEq(address(ZAPPING_PROXY).balance, 0, "ETH dust left in proxy");
    }

    /// @dev Builds an ETH zap whose router refunds part of the forwarded value, leaving dust.
    function _prepareEthZap() internal returns (ZapStruct memory zap, uint256 amountIn, uint256 amountOut, uint256 dust) {
        amountIn = 1 ether;
        amountOut = 1_000e6;
        dust = 0.1 ether;

        deal(address(this), amountIn);
        deal(address(USDC), address(router), amountOut);

        zap = ZapStruct({
            router: address(router),
            routerCall: abi.encodeCall(MockRouter.swapEth, (USDC, amountOut, receiver, dust))
        });
    }

    // ---------------------------------------------------------------- no behavioural regression

    /// @dev Every view the canonical handler serves must return byte-identical results afterwards,
    ///      otherwise dapps relying on the Safe's ERC-1271 / receiver hooks would break.
    function test_canonicalHandlerBehaviourIsPreserved() public {
        bytes[] memory calls = new bytes[](5);
        calls[0] = abi.encodeWithSignature("getMessageHash(bytes)", bytes("tangent"));
        calls[1] = abi.encodeWithSignature("getMessageHashForSafe(address,bytes)", OWNER_SAFE, bytes("tangent"));
        calls[2] = abi.encodeWithSignature("supportsInterface(bytes4)", bytes4(0x150b7a02));
        calls[3] = abi.encodeWithSignature("onERC721Received(address,address,uint256,bytes)", address(1), address(2), uint256(3), bytes(""));
        calls[4] = abi.encodeWithSignature("getModules()");

        uint256 length = calls.length;
        bool[] memory okBefore = new bool[](length);
        bytes[] memory before = new bytes[](length);
        for (uint256 i; i < length; ++i) {
            (okBefore[i], before[i]) = OWNER_SAFE.staticcall(calls[i]);
            // Guard against a vacuous comparison: every probe must genuinely resolve beforehand.
            assertTrue(okBefore[i], "probe did not resolve on the canonical handler");
        }

        _installHandler();

        for (uint256 i; i < length; ++i) {
            (bool okAfter, bytes memory result) = OWNER_SAFE.staticcall(calls[i]);
            assertEq(okAfter, okBefore[i], "success flag changed");
            assertEq(result, before[i], "handler return value changed");
        }
    }

    /// @dev ERC-1271 must still reject an unapproved message hash exactly as before.
    function test_isValidSignatureStillRejectsUnapprovedHash() public {
        bytes memory call = abi.encodeWithSignature("isValidSignature(bytes,bytes)", bytes("unapproved"), bytes(""));

        (bool okBefore, bytes memory before) = OWNER_SAFE.staticcall(call);
        assertFalse(okBefore, "unapproved hash unexpectedly accepted before the fix");

        _installHandler();
        (bool okAfter, bytes memory result) = OWNER_SAFE.staticcall(call);

        assertEq(okAfter, okBefore, "ERC-1271 success flag changed");
        assertEq(result, before, "ERC-1271 return value changed");
    }

    // ---------------------------------------------------------------- 0.7.6 vs 0.8.28 parity

    /// @dev The canonical handler was compiled with solc 0.7.6 (ABI coder v1); this one compiles
    ///      under 0.8.28 (coder v2, which validates calldata more strictly on decode). Since Safe's
    ///      FallbackManager appends 20 bytes of `msg.sender` to every forwarded call, every call
    ///      reaching the handler carries trailing calldata — precisely where a decoder-strictness
    ///      difference would surface. Fuzz well-formed inputs across the full handler surface and
    ///      require byte-identical (success, returndata) from both compilations.
    function testFuzz_handlerParityAcrossCompilers(bytes memory message, bytes4 interfaceId, address operator, uint256 tokenId) public {
        bytes[] memory calls = new bytes[](6);
        calls[0] = abi.encodeWithSignature("getMessageHash(bytes)", message);
        calls[1] = abi.encodeWithSignature("getMessageHashForSafe(address,bytes)", OWNER_SAFE, message);
        calls[2] = abi.encodeWithSignature("supportsInterface(bytes4)", interfaceId);
        calls[3] = abi.encodeWithSignature("onERC721Received(address,address,uint256,bytes)", operator, operator, tokenId, message);
        calls[4] = abi.encodeWithSignature("onERC1155Received(address,address,uint256,uint256,bytes)", operator, operator, tokenId, tokenId, message);
        calls[5] = abi.encodeWithSignature("isValidSignature(bytes,bytes)", message, message);

        _assertParity(calls, true);
    }

    /// @dev Same parity requirement, but for deliberately malformed calldata: a valid selector
    ///      followed by arbitrary bytes. This is the case coder v1 and v2 are most likely to
    ///      disagree on, so it is fuzzed directly rather than reasoned about.
    /// @dev `supportsInterface(bytes4)` is deliberately excluded — it is the one selector that does
    ///      diverge, pinned explicitly in `test_knownDivergence_dirtyPaddedSupportsInterface`.
    function testFuzz_handlerParityOnMalformedCalldata(bytes memory garbage) public {
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = bytes4(keccak256("getMessageHash(bytes)"));
        selectors[1] = bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
        selectors[2] = bytes4(keccak256("getModules()"));

        bytes[] memory calls = new bytes[](selectors.length);
        for (uint256 i; i < selectors.length; ++i) {
            calls[i] = abi.encodePacked(selectors[i], garbage);
        }

        _assertParity(calls, false);
    }

    /// @notice KNOWN, ACCEPTED DIVERGENCE between the 0.7.6 canonical handler and this 0.8.28 build.
    /// @dev    ABI coder v1 (solc 0.7.6) does not validate the padding bits of a `bytes4` argument:
    ///         it masks the high 4 bytes and answers. Coder v2 (solc 0.8.28, the default from 0.8.0)
    ///         requires the low 28 bytes to be zero and reverts otherwise.
    ///
    ///         Consequence: a caller that hand-builds `supportsInterface` calldata with dirty
    ///         padding gets `true`/`false` from the canonical handler but a revert from this one.
    ///         Any caller using `abi.encodeWithSelector` / a normal ABI encoder pads cleanly and is
    ///         unaffected — which is why the well-formed fuzz campaign shows full parity.
    ///
    ///         This test pins the divergence so it stays visible and any future change is caught.
    function test_knownDivergence_dirtyPaddedSupportsInterface() public {
        // ERC-721 receiver interface id, with non-zero padding bits appended.
        bytes memory call = abi.encodePacked(
            bytes4(keccak256("supportsInterface(bytes4)")),
            bytes4(0x150b7a02),
            bytes28(uint224(1))
        );

        (bool okBefore, bytes memory before) = OWNER_SAFE.staticcall(call);
        assertTrue(okBefore, "canonical handler unexpectedly reverted on dirty padding");
        assertEq(abi.decode(before, (bool)), true, "canonical handler should mask and answer true");

        _installHandler();

        (bool okAfter, bytes memory result) = OWNER_SAFE.staticcall(call);
        assertFalse(okAfter, "0.8.28 build unexpectedly accepted dirty padding");
        assertEq(result.length, 0, "expected a bare decoder revert");
    }

    /// @dev Cleanly padded `supportsInterface` — the path every real caller takes — must be
    ///      byte-identical across both compilations for every possible interface id.
    function testFuzz_supportsInterfaceParityWhenCleanlyPadded(bytes4 interfaceId) public {
        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("supportsInterface(bytes4)", interfaceId);
        _assertParity(calls, true);
    }

    /// @dev Records (success, returndata) for each call under the canonical handler, installs the
    ///      new one, and requires every result to be unchanged.
    /// @param compareRevertData When false, reverts need only agree on *whether* they revert, not on
    ///        the error bytes. Malformed calldata legitimately produces different revert payloads:
    ///        solc 0.8 has `Panic(uint256)` (e.g. 0x41, over-allocation) where 0.7.6 emitted a bare
    ///        revert. Both refuse the call; only the diagnostic bytes differ, which no caller relying
    ///        on this handler's documented behaviour can observe as a change in outcome.
    function _assertParity(bytes[] memory calls, bool compareRevertData) internal {
        uint256 length = calls.length;
        bool[] memory okBefore = new bool[](length);
        bytes[] memory before = new bytes[](length);

        for (uint256 i; i < length; ++i) {
            (okBefore[i], before[i]) = OWNER_SAFE.staticcall(calls[i]);
        }

        _installHandler();

        for (uint256 i; i < length; ++i) {
            (bool okAfter, bytes memory result) = OWNER_SAFE.staticcall(calls[i]);
            assertEq(okAfter, okBefore[i], "success flag diverged between compilations");
            if (okAfter || compareRevertData) {
                assertEq(result, before[i], "returndata diverged between compilations");
            }
        }
    }

    receive() external payable {}
}

/// @notice Re-runs the entire suite against the ACTUAL DEPLOYED handler bytecode at
///         0x055E53A75598E570ad7970AF4Cd34E3877817dCf, rather than a locally compiled copy.
///         This is what the pending Safe transaction would install.
contract DeployedFeeTreasuryFallbackHandlerTest is FeeTreasuryFallbackHandlerTest {
    address internal constant DEPLOYED_HANDLER = 0x055E53A75598E570ad7970AF4Cd34E3877817dCf;

    function _handlerUnderTest() internal pure override returns (FeeTreasuryFallbackHandler) {
        return FeeTreasuryFallbackHandler(DEPLOYED_HANDLER);
    }

    function test_deployedHandlerIsWiredToTheRealControlTower() public view {
        assertGt(DEPLOYED_HANDLER.code.length, 0, "no code at deployed handler");
        assertEq(address(FeeTreasuryFallbackHandler(DEPLOYED_HANDLER).controlTower()), CONTROL_TOWER);
        assertTrue(DEPLOYED_HANDLER != OWNER_SAFE, "handler must not be the Safe itself (GS400)");
    }
}
