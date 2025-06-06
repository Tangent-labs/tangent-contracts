// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "../../../contexts/MarketDeploymentContext.sol";

contract AddNewLockReward is MarketDeploymentContext {
    function test_addNewLockReward() external {
        vm.startPrank(owner);
        skip(7 days);
        rsTan.addNewReward(AddrClassicERC20.CRV);

        assertEq(address(tgUSD), address(rsTan.rewardTokens(0)));
        assertEq(address(AddrClassicERC20.CRV), address(rsTan.rewardTokens(1)));

        assertEq(rsTan.getRewardData(tgUSD).lastUpdateTime, block.timestamp - 7 days);
        assertEq(rsTan.getRewardData(AddrClassicERC20.CRV).lastUpdateTime, block.timestamp);
    }

    function test_addNewLockReward_fails_on_already_added_reward() external {
        vm.startPrank(owner);
        skip(7 days);

        vm.expectRevert(abi.encodeWithSelector(RsTan.RewardAlreadyAdded.selector, address(tgUSD)));
        rsTan.addNewReward(tgUSD);
    }
}
