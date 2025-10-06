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
        hLpManipulator.dumpCrvPool(lpDeploymentContext.USGLPs("USG-USDC"), 0, 1, 450_000 * 10 ** 6);
        hLpManipulator.dumpCrvPool(lpDeploymentContext.USGLPs("USG-wcrvUSD"), 0, 1, 450_000 * 10 ** 18);

        // console.log("benef", pegKeeperUSG_USDC.calc_profit());

        skip(1 days);

        uint256 priceOracle = lpDeploymentContext.USGLPs("USG-USDC").price_oracle(0);
        uint256 priceOracle2 = lpDeploymentContext.USGLPs("USG-wcrvUSD").price_oracle(0);
        vm.startPrank(owner);
        usg.mintPegKeeper(address(pegKeeperUSG_USDC), 2_000_000 ether);
        usg.mintPegKeeper(address(pegKeeperUSG_wcrvUSD), 2_000_000 ether);
        vm.stopPrank();

        pegKeeperUSG_USDC.update(owner);
        pegKeeperUSG_wcrvUSD.update(owner);

        pegKeeperUSG_USDC.withdraw_profit();
    }
}
