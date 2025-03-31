// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/ConvexCurveContext.sol";

import "../../handler/Curve/HLpManipulator.sol";

contract PegKeeperTest is ConvexCurveContext {
    HLpManipulator public hLpManipulator;
    function setUp() public {
        hLpManipulator = new HLpManipulator(usr1);
    }
    function test_pegKeeper_take_profit() external {
        // Dump a lot of FRXETH in the LP to depeg FRXETH
        hLpManipulator.dumpCrvPool(lpDeploymentContext.tgUSDLPs("tgUSD-USDC"), 0, 1, 100_000 * 10 ** 6);
        hLpManipulator.dumpCrvPool(lpDeploymentContext.tgUSDLPs("tgUSD-wfrxUSD"), 0, 1, 100_000 * 10 ** 18);

        console.log("Bal USDC", AddrClassicERC20.TOKEN_USDC.balanceOf(address(lpDeploymentContext.tgUSDLPs("tgUSD-USDC"))));
        console.log("Bal tgUSD", tgUSD.balanceOf(address(lpDeploymentContext.tgUSDLPs("tgUSD-USDC"))));

        // console.log("benef", pegKeeperTgUSD_USDC.calc_profit());

        skip(2000);

        deal(address(tgUSD), address(pegKeeperTgUSD_USDC), 2_000_000 ether);
        deal(address(tgUSD), address(pegKeeperTgUSD_frxUSD), 2_000_000 ether);

        pegKeeperTgUSD_USDC.update(owner);
        pegKeeperTgUSD_frxUSD.update(owner);

        pegKeeperTgUSD_USDC.withdraw_profit();
    }
}
