// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract USGMint is MarketDeploymentContext {
    function test_USG_init() external {
        assertEq(tgUSD.owner(), owner);
        assertEq(address(tgUSD.controlTower()), address(controlTower));
    }

    function test_mint_USG() external {
        vm.prank(owner);
        controlTower.toggleMarket(usr1);

        verifyReceiveERC20(tgUSD, usr2, 10 ether);
        verifyMintERC20(tgUSD, 10 ether);
        vm.prank(usr1);
        tgUSD.mint(usr2, 10 ether);
        assertERC20Tracking();
    }

    function test_mintIR_USG() external {
        vm.prank(owner);
        controlTower.toggleIRCalculator(usr1);

        verifyReceiveERC20(tgUSD, controlTower.feeTreasury(), 10 ether);
        verifyMintERC20(tgUSD, 10 ether);
        vm.prank(usr1);
        tgUSD.mintIR(10 ether);
        assertERC20Tracking();
    }

    function test_mintPegKeeper_USG() external {
        verifyReceiveERC20(tgUSD, address(pegKeeperTgUSD_USDC), 1_000_000 ether);
        verifyMintERC20(tgUSD, 1_000_000 ether);
        vm.prank(owner);
        tgUSD.mintPegKeeper(address(pegKeeperTgUSD_USDC), 1_000_000 ether);
        assertERC20Tracking();
    }
}
