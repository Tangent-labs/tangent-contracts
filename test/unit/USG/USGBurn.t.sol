// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract USGBurn is MarketDeploymentContext {
    uint256 amount = 100_000 ether;
    function setUp() external {
        vm.prank(owner);
        controlTower.toggleMarket(usr1);

        vm.prank(usr1);
        usg.mint(usr2, amount);
    }

    function test_burnFrom_USG() external {
        verifyLostERC20(usg, usr2, amount);
        verifyBurnERC20(usg, amount);
        vm.prank(usr1);
        usg.burnFrom(usr2, amount);
        assertERC20Tracking();
    }

    function test_burn_USG() external {
        verifyLostERC20(usg, usr2, amount);
        verifyBurnERC20(usg, amount);
        vm.prank(usr2);
        usg.burn(amount);
        assertERC20Tracking();
    }
}
