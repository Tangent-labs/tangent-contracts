// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import {FeeDispatcher} from "../../../src/USG/Utilities/FeeDispatcher.sol";
import {OracleCurveEmaOrSpot} from "../../../src/USG/Oracles/Token/OracleCurveEmaOrSpot.sol";
import {MockOracle} from "../../../src/mock/MockOracle.sol";

/// @dev Regression tests of the FeeDispatcher / OracleCurveEmaOrSpot audit findings
contract FeeDispatcherAuditPoC is MarketDeploymentContext {
    FeeDispatcher dispatcher;
    MockOracle crvOracle;
    address receiver;
    IERC20 crv = IERC20(address(AddrClassicERC20.CRV));
    address constant DAO = 0xd2c46b4c28f4B7976d9f87687863c46Bb2f71Dbb;
    address constant OLD_USDC_CRVUSD = 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E;

    function setUp() external {
        vm.startPrank(owner);
        dispatcher = new FeeDispatcher(owner, usg, zappingProxy, USGOracle, DAO);
        controlTower.setFeeTreasury(address(dispatcher));
        crvOracle = new MockOracle();
        crvOracle.setLastAnswer(0.5 ether);
        dispatcher.setTokenConfig(crv, crvOracle, 100);
        vm.stopPrank();
        receiver = address(dispatcher.receiver());
        deal(address(crv), address(dispatcher), 10_000 ether);
        deal(address(usg), address(mockRouter), 1_000_000 ether);
    }

    function _dump(uint256 amountIn, uint256 minOut) internal {
        FeeDispatcher.DumpParams[] memory dumps = new FeeDispatcher.DumpParams[](1);
        dumps[0] = FeeDispatcher.DumpParams({
            tokenIn: crv,
            amountIn: amountIn,
            minAmountOut: minOut,
            zap: ZapStruct({router: address(mockRouter), routerCall: abi.encodeCall(MockRouter.swap, (crv, amountIn, usg, receiver, minOut))})
        });
        dispatcher.dump(dumps);
    }

    /// M-01: a 0 price can't be configured nor used for a 0 floor
    function test_zeroPrice_rejected() external {
        MockOracle zero = new MockOracle();
        zero.setLastAnswer(0);
        vm.prank(owner);
        vm.expectRevert(FeeDispatcher.InvalidPrice.selector);
        dispatcher.setTokenConfig(crv, zero, 100);

        crvOracle.setLastAnswer(0);
        vm.expectRevert(FeeDispatcher.InvalidPrice.selector);
        _dump(10_000 ether, 0);
    }

    /// L-03: misdetected old stableswap fails at deployment
    function test_oldStableswap_reverts_at_deployment() external {
        vm.expectRevert();
        new OracleCurveEmaOrSpot(OLD_USDC_CRVUSD, oracles[AddrClassicERC20.USDC], 0, false, "crvUSD");
    }

    /// L-04: old pools (include_index = false) expose get_p()
    function test_oldPool_get_p_without_index() external view {
        assertGt(ICurveStableSwapNG(OLD_USDC_CRVUSD).get_p(), 0);
    }

    /// L-05: dust can't trigger the weekly dispatch
    function test_dispatch_min() external {
        deal(address(usg), address(dispatcher), 1_000 ether - 1);
        vm.expectRevert(FeeDispatcher.DispatchTooLow.selector);
        dispatcher.dispatch();
    }

    /// I-04: a reverting USG oracle doesn't break getTokens
    function test_getTokens_usgOracle_reverts() external {
        vm.mockCallRevert(address(USGOracle), abi.encodeWithSelector(IAggregatorStablePriceV3.price.selector), "");
        FeeDispatcher.TokenWithConfig[] memory tokens = dispatcher.getTokens();
        assertEq(tokens[0].balance, 10_000 ether);
        assertEq(tokens[0].floor, 0);
    }

    function test_dao_zero_rejected() external {
        vm.expectRevert(FeeDispatcher.InvalidDao.selector);
        new FeeDispatcher(owner, usg, zappingProxy, USGOracle, address(0));
    }

    function test_setDao() external {
        vm.prank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        dispatcher.setDao(usr1);

        vm.startPrank(owner);
        vm.expectRevert(FeeDispatcher.InvalidDao.selector);
        dispatcher.setDao(address(0));

        dispatcher.setDao(usr2);
        dispatcher.claim(crv, 1 ether);
        vm.stopPrank();
        assertEq(dispatcher.dao(), usr2);
        assertEq(crv.balanceOf(usr2), 1 ether, "Claim goes to the new DAO");
    }
}
