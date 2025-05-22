// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract SetHarvesterFeePercentage is MarketDeploymentContext {
    IERC20Metadata public collatToken = AddrCurveStableLP.WETH_frxETH;
    ConvexCrvLPMarket public market;

    function setUp() public {
        market = deployConvexCurveLPMarket(collatToken, true);
    }

    function test_setHarvesterFeePercentage_success() external {
        vm.startPrank(owner);
        rewardAccumulator.setHarvesterFeePercentage(address(market), 200);

        RCParams memory _params = rewardAccumulator.getRCParams(address(market));
        assertEq(_params.harvestFeePercentage, 200);
    }

    function test_setHarvesterFeePercentage_fails_because_too_high() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.HarvesterFeeTooHigh.selector));
        rewardAccumulator.setHarvesterFeePercentage(address(market), 3_000);
    }
}
