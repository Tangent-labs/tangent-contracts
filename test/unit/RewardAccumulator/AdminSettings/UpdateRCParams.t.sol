// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract UpdateRCParams is MarketDeploymentContext {
    IERC20Metadata public collatToken = AddrCurveStableLP.WETH_frxETH;
    ConvexCrvLPMarket public market;

    function setUp() public {
        market = deployConvexCurveLPMarket(collatToken);
    }

    RCParams params = RCParams({harvestFeePercentage: 0, stepAmount: 1, startCutPercentage: 0, endCutPercentage: 0, startCutPrice: 0, endCutPrice: 0});

    function test_updateRCParams_success() external {
        vm.startPrank(owner);
        rewardAccumulator.updateRCParams(address(market), params);

        RCParams memory _params = rewardAccumulator.getRCParams(address(market));
        assertEq(_params.harvestFeePercentage, 0);
        assertEq(_params.stepAmount, 1);
        assertEq(_params.startCutPercentage, 0);
        assertEq(_params.endCutPercentage, 0);
        assertEq(_params.startCutPrice, 0);
        assertEq(_params.endCutPrice, 0);
    }

    function test_updateRCParams_fails_stepAmountZero() external {
        vm.startPrank(owner);
        params.stepAmount = 0;
        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.StepAmountZero.selector));
        rewardAccumulator.updateRCParams(address(market), params);
    }

    function test_updateRCParams_fails_harvestFeeTooHigh() external {
        vm.startPrank(owner);
        params.harvestFeePercentage = 3_000;
        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.HarvesterFeeTooHigh.selector));
        rewardAccumulator.updateRCParams(address(market), params);
    }

    function test_updateRCParams_fails_startCutPrice_over_1() external {
        vm.startPrank(owner);
        params.startCutPrice = 2e18;
        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.StartCutPriceTooHigh.selector));
        rewardAccumulator.updateRCParams(address(market), params);
    }

    function test_updateRCParams_fails_endCutPerc_over_100() external {
        vm.startPrank(owner);
        params.startCutPrice = 10 ** 6;
        params.endCutPercentage = 100_001;
        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.EndCutPercentageBiggerThan100.selector));
        rewardAccumulator.updateRCParams(address(market), params);
    }

    function test_updateRCParams_fails_startCutPerc_over_100() external {
        vm.startPrank(owner);
        params.startCutPrice = 10 ** 6;
        params.endCutPercentage = 100_000;
        params.startCutPercentage = 100_001;
        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.StartCutPercentageBiggerThan100.selector));
        rewardAccumulator.updateRCParams(address(market), params);
    }

    function test_updateRCParams_fails_startCutPerc_bigger_than_endPercentage() external {
        vm.startPrank(owner);
        params.stepAmount = 2;

        params.startCutPercentage = 100_000;
        params.endCutPercentage = 99_000;

        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.StartCutPercentageBiggerThanEnd.selector));
        rewardAccumulator.updateRCParams(address(market), params);
    }

    function test_updateRCParams_fails_startCutPrice_smaller_than_endPrice() external {
        vm.startPrank(owner);
        params.stepAmount = 3;

        params.startCutPrice = 990_000;
        params.endCutPrice = 10 ** 6;

        params.startCutPercentage = 50_000;
        params.endCutPercentage = 100_000;

        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.StartCutPriceSmallerThanEnd.selector));
        rewardAccumulator.updateRCParams(address(market), params);
    }
}
