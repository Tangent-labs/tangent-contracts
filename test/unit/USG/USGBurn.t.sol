// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract USGBurn is MarketDeploymentContext {
    uint256 amount = 100_000 ether;
    function setUp() external {
        vm.prank(owner);
        controlTower.toggleMarket(usr1);

        vm.prank(usr1);
        tgUSD.mint(usr2, amount);
    }

    function test_burnFrom_USG() external {
        verifyLostERC20(tgUSD, usr2, amount);
        verifyBurnERC20(tgUSD, amount);
        vm.prank(usr1);
        tgUSD.burnFrom(usr2, amount);
        assertERC20Tracking();
    }

    function test_burn_USG() external {
        verifyLostERC20(tgUSD, usr2, amount);
        verifyBurnERC20(tgUSD, amount);
        vm.prank(usr2);
        tgUSD.burn(amount);
        assertERC20Tracking();
    }
}
