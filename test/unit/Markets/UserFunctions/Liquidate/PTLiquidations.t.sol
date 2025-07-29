// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../../contexts/MarketDeploymentContext.sol";

import "../../../../handler/Features/BorrowRepay/HBorrow.sol";
import "../../../../handler/Curve/HLPManipulator.sol";
import "../../../../handler/Features/HProcessRewards.sol";
import "../../../../handler/Features/ConvexCrv/HDepositConvexCrvLP.sol";
import "../../../../handler/Features/ConvexFxn/HDepositConvexFxnLP.sol";

import "../../../../../src/USG/Utilities/PendleCurveRouter.sol";
contract PTLiquidations is MarketDeploymentContext {
    BasicERC20Market public marketGho;

    IERC20Metadata public collatToken;

    PendleCurveRouter public pendleCurveRouter;

    function setUp() public {
        collatToken = AddrPTPendle.sUSDe_31_07_25;

        marketGho = deployBasicERC20Market(collatToken);

        pendleCurveRouter = new PendleCurveRouter();
    }

    function test_secondaryLiquidator_liquidate_PT() external {
        // Liquidation passes after IR increased the user debt over the liquidation threshold

        deal(address(collatToken), address(pendleCurveRouter), 100 ether);

        (address sy, address pt, address yt) = AddrMarketPendle.sUSDe_31_07_25.readTokens();

        pendleCurveRouter.swapPtForToken(PendlePTToSY({market: address(AddrMarketPendle.sUSDe_31_07_25), pt: address(AddrPTPendle.sUSDe_31_07_25)  sy :}));

        AddrClassicERC20.USDe.balanceOf(address(pendleCurveRouter));
        AddrERC4626.sUSDe.balanceOf(address(pendleCurveRouter));

        // assertEq(market_crvUSD_USDC.userDebt(usr1), 0);
        // assertEq(market_crvUSD_USDC.totalDebt(), 0);
        // assertEq(market_crvUSD_USDC.totalCollateral(), 0);
        // assertEq(market_crvUSD_USDC.collateralBalances(usr1), 0);
        vm.stopPrank();
    }
}
