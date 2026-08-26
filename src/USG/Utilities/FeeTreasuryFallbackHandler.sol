// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {CompatibilityFallbackHandler} from "@safe/handler/CompatibilityFallbackHandler.sol";

import {IControlTower} from "../../interfaces/internals/USG/IControlTower.sol";

/// @title FeeTreasuryFallbackHandler
/// @author Tangent Finance
/// @notice Safe fallback handler that additionally answers `feeTreasury()` by forwarding to the
///         real ControlTower.
/// @dev    The deployed ZappingProxy (0xa9e0021d8917c51f496823605d218d7e78719c99) was constructed
///         with the owner Safe (0x461B62CB3A7e9Df8f800aE058AE92F855F2c27Ca) as its `controlTower`
///         instead of the real ControlTower (0xf3f7669dceed2f985815011c19ed68f667267215). Its
///         `controlTower` slot has no setter and every market bakes the proxy address in at
///         construction, so the proxy cannot be repointed or replaced without redeploying markets.
///
///         Safe's FallbackManager forwards unknown selectors to the fallback handler with a plain
///         `call` and returns the handler's returndata verbatim, so installing this handler on the
///         Safe makes `controlTower.feeTreasury()` resolve for the ZappingProxy.
///
///         `feeTreasury()` delegates to the ControlTower rather than returning a hardcoded address,
///         so `ControlTower.setFeeTreasury` keeps working: rotating the treasury there is reflected
///         here immediately, with no handler redeploy and no second source of truth.
///
///         Extends the canonical 1.4.1 CompatibilityFallbackHandler rather than replacing it, so
///         ERC-1271 `isValidSignature` and the ERC-721/1155/777 receiver hooks are preserved. Note
///         that `CompatibilityFallbackHandler` resolves the Safe as `msg.sender`, which is why this
///         must inherit the handler rather than forward to the existing one.
contract FeeTreasuryFallbackHandler is CompatibilityFallbackHandler {
    /// @notice The real ControlTower this handler reads the fee treasury from.
    IControlTower public immutable controlTower;

    error ZeroAddress();
    error FeeTreasuryNotSet();

    constructor(IControlTower _controlTower) {
        require(address(_controlTower) != address(0), ZeroAddress());
        controlTower = _controlTower;
    }

    /// @notice Returns the protocol fee treasury, read live from the ControlTower.
    /// @return The current fee treasury address.
    function feeTreasury() external view returns (address) {
        return controlTower.feeTreasury();
    }
}
