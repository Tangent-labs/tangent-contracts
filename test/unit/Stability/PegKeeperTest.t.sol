// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Curve/HLPManipulator.sol";

contract PegKeeperTest is MarketDeploymentContext {
    HLPManipulator public hLpManipulator;
    function setUp() public {
        hLpManipulator = new HLPManipulator(usr1);
    }
    function test_pegKeeper_take_profit() external {
        // Dump a lot of FRXETH in the LP to depeg FRXETH
        hLpManipulator.dumpCrvPool(lpDeploymentContext.tgUSDLPs("tgUSD-USDC"), 0, 1, 450_000 * 10 ** 6);
        hLpManipulator.dumpCrvPool(lpDeploymentContext.tgUSDLPs("tgUSD-wfrxUSD"), 0, 1, 450_000 * 10 ** 18);

        // console.log("benef", pegKeeperTgUSD_USDC.calc_profit());

        skip(1 days);

        uint256 priceOracle = lpDeploymentContext.tgUSDLPs("tgUSD-USDC").price_oracle(0);
        uint256 priceOracle2 = lpDeploymentContext.tgUSDLPs("tgUSD-wfrxUSD").price_oracle(0);
        vm.startPrank(owner);
        tgUSD.mintPegKeeper(address(pegKeeperTgUSD_USDC), 2_000_000 ether);
        tgUSD.mintPegKeeper(address(pegKeeperTgUSD_frxUSD), 2_000_000 ether);
        vm.stopPrank();

        pegKeeperTgUSD_USDC.update(owner);
        pegKeeperTgUSD_frxUSD.update(owner);

        pegKeeperTgUSD_USDC.withdraw_profit();
    }
}
