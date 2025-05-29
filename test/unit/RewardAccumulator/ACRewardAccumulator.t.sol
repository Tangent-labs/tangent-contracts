// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";

contract ACRewardAccumulator is MarketDeploymentContext {
    IERC20Metadata public collatToken = AddrCurveStableLP.WETH_frxETH;
    ConvexCrvLPMarket public market;

    function setUp() public {
        market = deployConvexCurveLPMarket(collatToken, true);
    }

    function test_claimSimple_fails_on_not_a_market() external {
        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.NotAMarketRewards.selector));
        rewardAccumulator.claimSimple(usr1);
    }

    function test_addNewRewards_fails_as_not_owner() external {
        vm.startPrank(usr1);
        IERC20[] memory rewards = new IERC20[](1);
        rewards[0] = IERC20(address(AddrClassicERC20.CRV));
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        rewardAccumulator.addNewRewards(usr1, rewards);
    }

    function test_setHarvesterFeePercentage_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        rewardAccumulator.setHarvesterFeePercentage(usr1, 10);
    }

    function test_processRewards_fails_as_the_market_is_not_a_market() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.NotAMarketRewards.selector));
        rewardAccumulator.processRewards(usr1, usr1);
    }

    function test_processMultiRewards_fails_as_one_of_the_market_is_not_a_market() external {
        vm.startPrank(usr1);
        address[] memory markets = Array.memoryAddress([address(market), usr1]);
        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.NotAMarketRewards.selector));
        rewardAccumulator.processMultiRewards(markets, usr1, 2);
    }

    RCParams params = RCParams({harvestFeePercentage: 0, stepAmount: 0, startCutPercentage: 0, endCutPercentage: 0, startCutPrice: 0, endCutPrice: 0});

    function test_initializeMarket_fails_as_not_a_market_creator() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.CallerNotMarketCreator.selector, usr1));
        rewardAccumulator.initializeMarket(usr1, params);
    }

    function test_updateRCParams_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        rewardAccumulator.updateRCParams(address(market), params);
    }

    function test_updateRCParams_fails_as_the_market_is_not_one() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.NotAMarketRewards.selector));
        rewardAccumulator.updateRCParams(usr1, params);
    }

    function test_updateRewards_fails_as_the_market_is_not_a_market() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(RewardAccumulator.NotAMarketRewards.selector));
        rewardAccumulator.updateRewards(usr1, 100, 100);
    }
}
