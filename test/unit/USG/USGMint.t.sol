// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract USGMint is MarketDeploymentContext {
    function test_USG_init() external view {
        assertEq(usg.owner(), owner);
        assertEq(address(usg.controlTower()), address(controlTower));
    }

    function test_mint_USG() external {
        vm.prank(owner);
        controlTower.toggleMarket(usr1);

        verifyReceiveERC20(usg, usr2, 10 ether);
        verifyMintERC20(usg, 10 ether);
        vm.prank(usr1);
        usg.mint(usr2, 10 ether);
        assertERC20Tracking();
    }

    function test_mintIR_USG() external {
        vm.prank(owner);
        controlTower.toggleIRCalculator(usr1);

        verifyReceiveERC20(usg, controlTower.feeTreasury(), 10 ether);
        verifyMintERC20(usg, 10 ether);
        vm.prank(usr1);
        usg.mintIR(10 ether);
        assertERC20Tracking();
    }

    function test_mintPegKeeper_USG() external {
        verifyReceiveERC20(usg, address(pegKeeperUSG_USDC), 1_000_000 ether);
        verifyMintERC20(usg, 1_000_000 ether);
        vm.prank(owner);
        usg.mintPegKeeper(address(pegKeeperUSG_USDC), 1_000_000 ether);
        assertERC20Tracking();
    }
}
