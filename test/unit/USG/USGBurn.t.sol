// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract USGBurn is MarketDeploymentContext {
    uint256 amount = 100_000 ether;
    function setUp() external {
        vm.startPrank(owner);
        usg.setIsMinter(usr1, true);
        usg.setIsBurner(usr1, true);
        vm.stopPrank();
        vm.prank(usr1);
        usg.mintDebt(usr2, amount);
    }

    function test_burnFrom_USG() external {
        verifyLostERC20(usg, usr2, amount);
        verifyBurnERC20(usg, amount);
        vm.prank(usr1);
        usg.burnDebt(usr2, amount);
        assertERC20Tracking();
    }

    function test_burn_USG() external {
        verifyLostERC20(usg, usr2, amount);
        verifyBurnERC20(usg, amount);
        vm.prank(usr2);
        usg.burn(amount);
        assertERC20Tracking();
    }

    function test_burnPegkeeper_USG() external {
        vm.startPrank(owner);
        usg.mintPegKeeper(address(pegKeeperUSG_USDC), amount);
        verifyLostERC20(usg, address(pegKeeperUSG_USDC), amount);
        verifyBurnERC20(usg, amount);
        usg.burnPegKeeper(address(pegKeeperUSG_USDC), amount);
        assertERC20Tracking();
        vm.expectRevert();
        usg.burnPegKeeper(address(pegKeeperUSG_USDC), 1);
    }
}
