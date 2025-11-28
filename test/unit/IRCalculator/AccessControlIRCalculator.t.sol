// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../contexts/MarketDeploymentContext.sol";
contract AccessControlIRCalculator is MarketDeploymentContext {
    function test_setUSGOracle_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        irCalculator.setUSGOracle(IAggregatorStablePriceV3(usr2));
    }

    function test_initializeMarket_fails_as_not_market_creator() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(IRCalculator.CallerNotMarketCreator.selector));
        irCalculator.initializeMarket(usr2, IRParams(true, 0, 0, 0, 1, 2, 0, 0, 0));
    }

    function test_updateIRParams_fails_as_not_owner() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(LightOwnable.OwnableUnauthorizedAccount.selector, usr1));
        irCalculator.updateIRParams(usr2, IRParams(true, 0, 0, 0, 0, 0, 0, 0, 0));
    }

    function test_checkpointIR_fails_when_not_a_market() external {
        vm.startPrank(usr1);
        vm.expectRevert(abi.encodeWithSelector(IRCalculator.NotAMarket.selector));
        irCalculator.checkpointIR(usr2);
    }

    function test_checkpointIRMulti_fails_when_one_market_from_the_list_is_not_a_market() external {
        vm.startPrank(usr1);

        address[] memory users = Array.memoryAddress([usr2]);
        vm.expectRevert(abi.encodeWithSelector(IRCalculator.NotAMarket.selector));
        irCalculator.checkpointIRMulti(users);
    }
}
