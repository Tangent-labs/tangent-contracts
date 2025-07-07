// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract USGAccessControl is MarketDeploymentContext {
    uint256 amount;
    function test_mint_fails_call_not_by_a_market() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(USG.OnlyMarketCaller.selector));
        usg.mint(usr2, amount);
    }

    function test_mintIR_fails_call_not_by_an_IRCalculator() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(USG.OnlyIRCalculator.selector));
        usg.mintIR(amount);
    }

    function test_mintPegKeeper_fails_call_not_by_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        usg.mintPegKeeper(usr1, amount);
    }

    function test_mintPegKeeper_fails_mint_not_on_pegKeeper() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(USG.MintOnlyOnPegKeeper.selector));
        usg.mintPegKeeper(usr1, amount);
    }

    function test_burnFrom_fails_call_not_by_market() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(USG.OnlyMarketCaller.selector));
        usg.burnFrom(usr1, amount);
    }
}
