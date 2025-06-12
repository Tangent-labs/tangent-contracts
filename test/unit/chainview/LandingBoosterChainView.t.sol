// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Features/BorrowRepay/HBorrow.sol";

import "../../../src/chainview/boosters/LandingBooster.cv.sol";

contract LandingBoosterChainView is MarketDeploymentContext {
    ConvexCrvLPMarket public market1;
    ConvexCrvLPMarket public market2;

    // LIST
    function test_LandingBoosterChainView_ui_returns() public {
        //  ,0x508f0e1b565b40aeb94671bed228083203330882,0x35e30bc815935bb5ec1743f772331864d780cc26,0xaf5b3f4a0b4dc334db7137e5584e0e971e5e4962

        address[] memory params = Array.memoryAddress(
            [
                0x2FF160bcADb485b5F048b9880e6f471Af632060c,
                0x508f0E1b565b40AeB94671BeD228083203330882,
                0x35e30Bc815935Bb5EC1743f772331864D780cc26,
                0xAf5b3f4A0b4dc334dB7137E5584E0e971E5e4962
            ]
        );
        try new LandingBooster(params) {} catch (bytes memory reason) {
            assertTrue(reason.length > 3, "Chainview failed");
        }
    }
}
