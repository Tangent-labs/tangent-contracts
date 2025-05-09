// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract SetKick is MarketDeploymentContext {
    function test_setKick() external {
        vm.startPrank(owner);

        rsTan.setKick(KickParams({delay: 2.5 weeks, percentage: 3_000}));

        (uint128 delay, uint128 percentage) = rsTan.kick();
        assertEq(2.5 weeks, delay);
        assertEq(3_000, percentage);
    }

    function test_setKick_fails_onlyOwner() external {
        vm.startPrank(usr1);

        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        rsTan.setKick(KickParams({delay: 2 weeks, percentage: 20_001}));
    }

    function test_setKick_fails_delay_too_short() external {
        vm.startPrank(owner);

        vm.expectRevert(abi.encodeWithSelector(RsTan.KickDelayTooShort.selector));
        rsTan.setKick(KickParams({delay: 1 days - 1, percentage: 1000}));
    }

    function test_setKick_fails_delay_too_long() external {
        vm.startPrank(owner);

        vm.expectRevert(abi.encodeWithSelector(RsTan.KickDelayTooLong.selector));
        rsTan.setKick(KickParams({delay: 4 weeks + 1, percentage: 1000}));
    }

    function test_setKick_fails_percentage_too_big() external {
        vm.startPrank(owner);

        vm.expectRevert(abi.encodeWithSelector(RsTan.KickPercentageTooHigh.selector));
        rsTan.setKick(KickParams({delay: 2 weeks, percentage: 20_001}));
    }
}
