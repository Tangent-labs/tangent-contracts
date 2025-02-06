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
        hLpManipulator.dumpCrvPool(lpDeploymentContext.tgUSDLPs("tgUSD-USDC"), 0, 1, 2000 * 10 ** 6);
        hLpManipulator.dumpCrvPool(lpDeploymentContext.tgUSDLPs("tgUSD-USDT"), 0, 1, 2000 * 10 ** 6);

        console.log("Bal USDC", AddrClassicERC20.TOKEN_USDC.balanceOf(address(lpDeploymentContext.tgUSDLPs("tgUSD-USDC"))));
        console.log("Bal tgUSD", tgUSD.balanceOf(address(lpDeploymentContext.tgUSDLPs("tgUSD-USDC"))));

        // console.log("benef", pegKeeperTgUSD_USDC.calc_profit());

        skip(2000);

        deal(address(tgUSD), address(pegKeeperTgUSD_USDC), 2_000_000 ether);
        deal(address(tgUSD), address(pegKeeperTgUSD_USDT), 2_000_000 ether);

        // console.log(
        //     AddrClassicERC20.TOKEN_USDC.balanceOf(address(lpDeploymentContext.tgUSDLPs("tgUSD-USDC"))),
        //     tgUSD.balanceOf(address(lpDeploymentContext.tgUSDLPs("tgUSD-USDC")))
        // );

        // console.log("allowed", pegKeeperRegulator.provide_allowed(address(pegKeeperTgUSD_USDC)));
        // console.log(pegKeeperTgUSD_USDC.estimate_caller_profit());
        pegKeeperTgUSD_USDC.update(owner);
        pegKeeperTgUSD_USDT.update(owner);

        pegKeeperTgUSD_USDC.withdraw_profit();
    }
}
