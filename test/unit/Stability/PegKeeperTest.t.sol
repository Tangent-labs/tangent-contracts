// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

import "../../handler/Curve/HLPManipulator.sol";

import "../../../src/chainview/USG/bot/OnchainTxBot.cv.sol";

contract PegKeeperTest is MarketDeploymentContext {
    HLPManipulator public hLpManipulator;
    function setUp() public {
        hLpManipulator = new HLPManipulator(usr1);

        vm.startPrank(owner);
        usg.mintPegKeeper(address(pegKeeperUSG_USDC), 2_000_000 ether);
        usg.mintPegKeeper(address(pegKeeperUSG_wcrvUSD), 2_000_000 ether);
        vm.stopPrank();
    }
    function test_pegKeeper_take_profit() external {
        // Dump a lot of FRXETH in the LP to depeg FRXETH
        hLpManipulator.dumpCrvPool(lpDeploymentContext.USGLPs("USG-USDC"), 0, 1, 450_000 * 10 ** 6);
        hLpManipulator.dumpCrvPool(lpDeploymentContext.USGLPs("USG-wcrvUSD"), 0, 1, 450_000 * 10 ** 18);

        skip(1 days);

        uint256 priceOracle = lpDeploymentContext.USGLPs("USG-USDC").price_oracle(0);
        uint256 priceOracle2 = lpDeploymentContext.USGLPs("USG-wcrvUSD").price_oracle(0);

        pegKeeperUSG_USDC.update(owner);
        pegKeeperUSG_wcrvUSD.update(owner);

        pegKeeperUSG_USDC.withdraw_profit();
    }

    function test_pegKeeper_chainview() external {
        IPegKeeperV2[] memory pegKeepers = new IPegKeeperV2[](2);
        pegKeepers[0] = pegKeeperUSG_USDC;
        pegKeepers[1] = pegKeeperUSG_wcrvUSD;

        IDebtIR[] memory emptyMarkets = new IDebtIR[](0);

        try new OnchainTxBot(pegKeepers, emptyMarkets) {} catch (bytes memory reason) {
            (uint256[] memory profits, ) = abi.decode(removeFirst4Bytes(reason), (uint256[], OnchainTxBot.IRAndRC[]));
            assertEq(profits[0], 0);
            assertEq(profits[1], 0);

            assertTrue(reason.length > 3, "Chainview failed");
        }

        hLpManipulator.dumpCrvPool(lpDeploymentContext.USGLPs("USG-USDC"), 0, 1, 100_000 * 10 ** 6);
        hLpManipulator.dumpCrvPool(lpDeploymentContext.USGLPs("USG-wcrvUSD"), 0, 1, 100_000 * 10 ** 18);

        uint256 priceOracle = lpDeploymentContext.USGLPs("USG-USDC").price_oracle(0);
        uint256 priceOracle2 = lpDeploymentContext.USGLPs("USG-wcrvUSD").price_oracle(0);
        skip(1 hours);

        assertLt(priceOracle, lpDeploymentContext.USGLPs("USG-USDC").price_oracle(0));
        assertLt(priceOracle2, lpDeploymentContext.USGLPs("USG-wcrvUSD").price_oracle(0));

        try new OnchainTxBot(pegKeepers, emptyMarkets) {} catch (bytes memory reason) {
            (uint256[] memory profits, ) = abi.decode(removeFirst4Bytes(reason), (uint256[], OnchainTxBot.IRAndRC[]));
            assertGt(profits[0], 0);
            assertGt(profits[1], 0);

            assertTrue(reason.length > 3, "Chainview failed");
        }
        pegKeeperUSG_USDC.update(usr1);
        pegKeeperUSG_wcrvUSD.update(usr1);

        skip(30 seconds);

        pegKeeperUSG_USDC.update(usr1);
        pegKeeperUSG_wcrvUSD.update(usr1);

        skip(30 seconds);

        pegKeeperUSG_USDC.update(usr1);
        pegKeeperUSG_wcrvUSD.update(usr1);
    }
}
